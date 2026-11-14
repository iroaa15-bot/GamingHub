"""Opt-in social games on the existing authenticated room/voice transport.

Draft source decks require GAMINGHUB_ENABLE_DRAFT_SOCIAL=1. This flag does not
approve their editorial quality and is disabled by default on hosted services.
"""
import os
import json
import re
import secrets
import time
import unicodedata
from pathlib import Path
from party_rooms import PartyRoom, CATEGORIES
from shared_quiz_local import SharedQuizHub
from photo_duel_extension import Room, ProtocolError, VERSION, integer
from room_codes_local import new_room_code


def load_social_deck():
    folder = Path(__file__).resolve().parents[1] / 'content/qaadet_el_sohab'
    cards, ids, prompts = [], set(), set()
    for path in sorted(folder.glob('*.json')):
        value = json.loads(path.read_text(encoding='utf-8'))
        if value.get('game_id') not in CATEGORIES | {'qaadet_el_sohab'}:
            raise ValueError('Unknown social catalog')
        for card in value['cards']:
            category, key, text = card.get('category'), card.get('id'), card.get('text_ar')
            if category not in CATEGORIES or not isinstance(key, str) or not key or not isinstance(text, str) or not text.strip() or len(text)>500:
                raise ValueError('Invalid social card')
            if key in ids:
                raise ValueError('Duplicate social ID')
            ids.add(key)
            normalized = ''.join(c for c in unicodedata.normalize('NFKD', text).casefold() if not unicodedata.combining(c) and c != '\u0640')
            normalized = normalized.translate(str.maketrans('أإآىة', 'ااايه'))
            prompt = (category, re.sub(r'[\W_]+', '', normalized))
            if prompt in prompts:
                continue
            prompts.add(prompt)
            cards.append(card.copy())
    if not cards or len(ids)>3000:
        raise ValueError('Invalid social deck size')
    return cards


class PowerMatch:
    """Authoritative counterpart of the existing local Table Flip rules."""
    LEGACY = dict(zip(range(1,23), ('swap','bonus','shield','choice','double','choice','choice','double','reverse','shield','skip','reverse','choice','reverse','skip','swap','choice','choice','double','bonus','shield','reverse')))

    def __init__(self, players, cards, rounds):
        self.players = tuple(players)
        self.cards = cards
        self.round_limit = rounds
        self.scores = dict.fromkeys(players, 0)
        self.shields = dict.fromkeys(players, 0)
        self.doubles = dict.fromkeys(players, 0)
        self.skips = dict.fromkeys(players, 0)
        self.order = list(players)
        self.turn = self.round_number = 0
        self.direction = 1
        self.used = set()
        self.current = None
        self.offered = []
        self.choose_next = False

    @property
    def actor(self):
        return self.order[self.turn]

    def draw(self, category='table_flip'):
        if self.current or self.offered or self.round_number>=self.round_limit:
            raise ValueError('Round already active or finished')
        available = [c for c in self.cards if c['id'] not in self.used]
        if not available:
            raise ValueError('Deck exhausted')
        if self.choose_next and len(available)>=2:
            self.offered = secrets.SystemRandom().sample(available, 2)
        else:
            self.current = secrets.choice(available).copy()
            self.used.add(self.current['id'])
        self.choose_next = False

    def choose(self, player, card_id):
        if player!=self.actor or not self.offered:
            raise ValueError('Only the active player chooses')
        card = next((c for c in self.offered if c['id']==card_id), None)
        if card is None:
            raise ValueError('Card was not offered')
        self.current = card.copy()
        self.used.add(card_id)
        self.offered = []

    def kind(self):
        value = self.current.get('power_type', '')
        if value:
            return value
        match = re.fullmatch(r'qs_power_(\d+)', self.current['id'])
        return self.LEGACY.get(int(match[1]), 'self_bonus') if match else 'self_bonus'

    def apply(self, player, target=None):
        if player!=self.actor or not self.current:
            raise ValueError('Only the active player applies this card')
        kind = self.kind()
        if kind in ('bonus','steal','skip') and (target not in self.players or target==player):
            raise ValueError('Choose another room member')
        awards = {}
        def grant(who, amount):
            if self.doubles[who]:
                amount *= 2
                self.doubles[who] -= 1
            self.scores[who] += amount
            awards[who] = awards.get(who,0)+amount
        if kind=='reverse': self.direction *= -1
        elif kind=='swap' and len(self.order)>=3:
            a,b = ((self.turn+n*self.direction)%len(self.order) for n in (1,2))
            self.order[a],self.order[b] = self.order[b],self.order[a]
        elif kind=='bonus': grant(target,5)
        elif kind=='steal':
            if self.shields[target]: self.shields[target]-=1
            else:
                amount=min(5,self.scores[target]);self.scores[target]-=amount
                awards[target]=-amount;grant(player,amount)
        elif kind=='shield': self.shields[player]+=1
        elif kind=='skip': self.skips[target]+=1
        elif kind=='double': self.doubles[player]+=1
        elif kind=='gift': grant(self.order[(self.turn+self.direction)%len(self.order)],5)
        elif kind=='choice': self.choose_next=True
        elif kind=='self_bonus': grant(player,5)
        elif kind!='swap': raise ValueError('Unknown power')
        self.current=None;self.round_number+=1
        self.turn=(self.turn+self.direction)%len(self.order)
        for _ in self.order:
            next_player=self.actor
            if not self.skips[next_player]: break
            self.skips[next_player]-=1
            self.turn=(self.turn+self.direction)%len(self.order)
        return {'awards':awards,'scores':self.scores.copy(),'round':self.round_number,'finished':self.round_number>=self.round_limit}

    def public_state(self, viewer):
        return {'actor':self.actor,'round':self.round_number,'card':self.current.copy() if self.current else None,
                'offered':[c.copy() for c in self.offered] if viewer==self.actor else [],
                'choosing':bool(self.offered),'power':self.kind() if self.current else '',
                'voted_players':[],'finished':self.round_number>=self.round_limit}


class SocialRoom(Room):
    def __init__(self, code, capacity, rounds, catalog, category, cards):
        super().__init__(code,capacity,0,rounds,catalog)
        self.category=category
        players=tuple(str(i) for i in range(capacity))
        deck=[c for c in cards if c['category']==category]
        self.core=PowerMatch(players,deck,rounds) if category=='table_flip' else PartyRoom(players,deck,rounds)
        self.agreement=True;self.config_revision=1;self.confirmed=[False]*capacity
        self.primary_mode='voice';self.picture_category='all';self.picture_difficulty='easy'
        self.phase='lobby';self.match_finished=False;self.last_result={}

    def begin(self):
        self.core.draw(self.category)
        self.current=int(self.core.actor);self.phase='active';self.pending=None
        self.timer=30 if self.category in ('act_it','show_skill') else 0
        self.arm()

    def finish_social(self, result):
        self.last_result=result
        self.scores=[self.core.scores[str(i)] for i in range(self.capacity)]
        self.current=int(self.core.actor);self.round=self.core.round_number+1
        self.deadline=None;self.remaining=None
        self.match_finished=bool(result['finished'])
        self.phase='finished' if self.match_finished else 'results'
        leaders=[i for i,s in enumerate(self.scores) if s==max(self.scores)]
        self.winner=leaders[0] if self.match_finished and len(leaders)==1 else -1

    def expire(self):
        if self.phase=='active' and not self.paused and self.deadline is not None and time.monotonic()>=self.deadline:
            for player in self.core.players:
                if player!=self.core.actor and player not in self.core.votes:self.core.vote(player,False)
            self.finish_social(self.core.finish())
            return True
        return False

    def view(self, player):
        value=super().view(player)
        social=self.core.public_state(str(player))
        social['card_id']=self.core.current['id'] if self.core.current else ''
        if self.category in ('act_it','show_skill') and str(player)!=self.core.actor and self.phase=='active':social['card']=None
        social.update(category=self.category,phase=self.phase,rounds=self.core.round_limit,result=self.last_result)
        value.update(party=social,opponents=[],preset_questions=[])
        return value


class SocialHub(SharedQuizHub):
    def __init__(self, secret, database, enable_social=None):
        super().__init__(secret,database)
        self.social_enabled=os.environ.get('GAMINGHUB_ENABLE_DRAFT_SOCIAL')=='1' if enable_social is None else enable_social
        self.social_cards=load_social_deck() if self.social_enabled else []
        self.social_requests={}

    async def send(self, ws, message):
        if message.get('type')=='duel_capabilities':message={**message,'party_games':sorted(CATEGORIES) if self.social_enabled else []}
        return await super().send(ws,message)

    async def handle(self, ws, msg):
        identity=self.identities.get(ws)
        if not identity or identity['exp']<=time.time() or type(msg.get('protocol')) is not int or msg['protocol']!=VERSION:
            raise ProtocolError('Invalid or expired transport identity')
        action=msg.get('type')
        if not isinstance(action,str):raise ProtocolError('Invalid social action')
        if action=='duel_hello' and str(msg.get('game_id','')).startswith('party:'):
            category=msg['game_id'][6:]
            if category not in CATEGORIES:raise ProtocolError('Unknown social game')
            self.social_requests[ws]=category
            return await super().handle(ws,{'type':'duel_hello','protocol':VERSION})
        if action=='duel_party_create':
            category=msg.get('category')
            if not self.social_enabled or not isinstance(category,str) or category not in CATEGORIES or self.social_requests.get(ws)!=category:raise ProtocolError('Social rooms unavailable')
            if ws in self.bindings or len(self.rooms)>=100:raise ProtocolError('Room capacity reached')
            capacity=integer(msg.get('players'),range(2,7));rounds=integer(msg.get('rounds'),(10,15,20))
            room=SocialRoom(new_room_code(self.rooms),capacity,rounds,self.catalog,category,self.social_cards)
            room.peers[0]=ws;room.joined=1;self.rooms[room.code]=room;self.bindings[ws]=(room.code,0)
            self.subjects[room.code]={0:identity['sub']}
            await self.send(ws,{'type':'duel_created','code':room.code,'token':room.tokens[0],'player':0})
            return await self.publish(room)
        if action in ('duel_join','duel_resume'):
            code=msg.get('code')
            if not isinstance(code,str):raise ProtocolError('Invalid room code')
            target=self.rooms.get(code)
            if isinstance(target,SocialRoom) and self.social_requests.get(ws)!=target.category:raise ProtocolError('Join from the same game')
            if not isinstance(target,SocialRoom) and ws in self.social_requests:raise ProtocolError('Join from the same game')
        binding=self.bindings.get(ws);room=self.rooms.get(binding[0]) if binding else None
        if not isinstance(room,SocialRoom):return await super().handle(ws,msg)
        player=binding[1]
        room.activity=time.monotonic()
        if action=='duel_party_propose':
            mode=msg.get('primary_mode')
            if player!=0 or room.started or mode not in ('voice','text','mixed','tap'):raise ProtocolError('Invalid host proposal')
            if mode!=room.primary_mode:
                self.reset_voice(room);room.primary_mode=mode;room.config_revision+=1;room.confirmed=[False]*room.capacity
            return await self.publish(room)
        if action=='duel_start':
            if player!=0 or room.started or room.paused or room.joined!=room.capacity or not all(room.confirmed) or not all(room.peers):raise ProtocolError('All players must be ready')
            room.started=True;room.begin();return await self.publish(room)
        if action.startswith('duel_party_'):
            if not room.started or room.paused or room.match_finished:raise ProtocolError('Match waiting, paused or finished')
            if room.expire():await self.publish(room)
            if action=='duel_party_next':
                if player!=0 or room.phase!='results' or type(msg.get('round')) is not int or msg['round']!=room.core.round_number:raise ProtocolError('Invalid next round')
                room.begin();return await self.publish(room)
            if room.phase!='active':raise ProtocolError('Round already completed')
            core=room.core;actor=str(player)
            if action=='duel_party_choose':
                if not isinstance(core,PowerMatch):raise ProtocolError('Not a power selection')
                core.choose(actor,msg.get('card_id'));return await self.publish(room)
            if not core.current or msg.get('card_id')!=core.current['id']:raise ProtocolError('Stale social card')
            if action=='duel_party_story':core.commit_story(actor,msg.get('is_true'))
            elif action=='duel_party_vote':
                core.vote(actor,msg.get('choice'))
                required=room.capacity if room.category=='who_among_us' else room.capacity-1
                if len(core.votes)==required:room.finish_social(core.finish())
            elif action=='duel_party_finish':
                if room.category!='open_heart' or actor!=core.actor or type(msg.get('participated')) is not bool:raise ProtocolError('Only the active player confirms participation')
                room.finish_social(core.finish(participated=msg['participated']))
            elif action=='duel_party_power':
                if not isinstance(core,PowerMatch):raise ProtocolError('Not a power card')
                room.finish_social(core.apply(actor,msg.get('target')))
            else:raise ProtocolError('Unknown social action')
            return await self.publish(room)
        if action not in ('duel_auth_bind','duel_accept','duel_sync','duel_leave','duel_voice_state','duel_voice_audio','duel_report','duel_block','duel_chat','duel_session_refresh'):
            raise ProtocolError('Action does not belong to this social game')
        return await super().handle(ws,msg)

    async def disconnect(self, ws):
        await super().disconnect(ws)
        self.social_requests.pop(ws,None)
