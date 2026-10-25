"""Opt-in Photo Duel room boundary. Not imported by the production room server.
The transport must bind player identity from a server-issued resume token, never JSON player fields.
"""
import json
import secrets
import time
from pathlib import Path
from photo_match_protocol import PhotoMatch, MatchError

CATALOG = Path(__file__).resolve().parents[1]/'data/guess_picture_302/catalog.json'

class PhotoRoom:
    def __init__(self, players, *, catalog=CATALOG, **settings):
        items=json.loads(Path(catalog).read_text(encoding='utf-8'))['items']
        self.catalog={x['id']: x for x in items if x['group']=='original_200' and x['rights_status']=='CORE_200_EXISTING_LIBRARY'}
        if len(self.catalog)<2: raise MatchError('At least two approved core images required')
        self.match=PhotoMatch(tuple(players),**settings)
        self.tokens={p:secrets.token_urlsafe(32) for p in players}
        self.disconnected={}
        self.closed=False
        self._assign()

    def _assign(self):
        self.secret_ids=secrets.SystemRandom().sample(list(self.catalog),2)
        self._facts()

    def _facts(self):
        # Player i guesses secret i, which ONLY the other player can see.
        self.match.server_facts=dict(self.catalog[self.secret_ids[self.match.current]]['facts'])

    def authenticate(self, token):
        for player, expected in self.tokens.items():
            if isinstance(token,str) and secrets.compare_digest(token,expected):return player
        raise MatchError('Invalid session')

    def resume(self, token):
        player=self.authenticate(token)
        since=self.disconnected.get(player)
        if self.closed or since is None or time.monotonic()-since>85:raise MatchError('Resume expired or session active')
        self.tokens[player]=secrets.token_urlsafe(32)
        del self.disconnected[player]
        return self.tokens[player],self.view(player)

    def disconnect(self, player):
        self.match._player(player)
        self.disconnected[player]=time.monotonic()

    def leave(self, player):
        self.match._player(player)
        self.closed=True
        self.tokens.clear()

    def view(self, player):
        index=self.match._player(player)
        item=self.catalog[self.secret_ids[1-index]]
        return {'type':'photo_state','current':self.match.current,'player':index,
                'round':self.match.round,'scores':self.match.scores.copy(),'target':self.match.target,
                'timer':self.match.timer,'reward':self.match.reward,
                'remaining':max(0,self.match.timer-int(time.monotonic()-self.match.turn_started)) if self.match.timer else None,
                'finished':self.match.finished,'closed':self.closed,
                'awaiting_confirmation':self.match.awaiting_confirmation,
                'pending_question':self.match.pending_question,
                'question_mode':self.match.question_mode,
                'visible_opponent_image':{'id':item['id'],'image':item['image']},
                'available_questions':list(self.catalog[self.secret_ids[index]]['facts'])}

    def handle(self, player, message):
        self.match._player(player)
        if self.closed or self.disconnected:raise MatchError('Room paused or closed')
        if not isinstance(message,dict):raise MatchError('Invalid message')
        # Expiration runs before admitting any action, including opponent replies.
        if self.match.expire_turn():self._facts()
        self._facts()
        action=message.get('type')
        if action=='photo_text':result=self.match.ask_text(player,message.get('text'))
        elif action=='photo_tap':result=self.match.ask_tap(player,message.get('question_id'))
        elif action=='photo_reply':result=self.match.reply(player,message.get('answer'))
        elif action=='photo_guess':result=self.match.propose_guess(player,message.get('guess',''))
        elif action=='photo_confirm':
            before=self.match.round
            result=self.match.confirm_guess(player,message.get('correct'))
            if self.match.round!=before:self._assign()
        elif action=='photo_pass':result=self.match.pass_turn(player)
        else:raise MatchError('Unsupported photo action')
        self._facts()
        return result
