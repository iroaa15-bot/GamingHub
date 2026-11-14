"""Actual shared-transport dispatch, membership and authoritative social rules."""
import asyncio
import json
import secrets
import unittest
from websockets.asyncio.server import serve
from websockets.asyncio.client import connect
from social_rooms import SocialHub, SocialRoom, PowerMatch, load_social_deck, CATEGORIES
from photo_duel_extension import ProtocolError
from pathlib import Path


class Peer:
    def __init__(self):self.messages=[]
    async def send(self, data):self.messages.append(json.loads(data))


class SocialTransportTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.hub=SocialHub(secrets.token_urlsafe(48),':memory:',True)
        self.peers=[Peer() for _ in range(6)]
        for index,peer in enumerate(self.peers):
            _,claims=self.hub.sessions.issue();self.hub.identities[peer]=claims

    async def asyncTearDown(self):self.hub.moderation.db.close()

    async def send(self,index,kind,**fields):
        await self.hub.handle(self.peers[index],{'protocol':3,'type':kind,**fields})

    async def create(self,category,capacity=3):
        for i in range(capacity):await self.send(i,'duel_hello',game_id='party:'+category)
        await self.send(0,'duel_party_create',category=category,players=capacity,rounds=10)
        room=self.hub.rooms[self.hub.bindings[self.peers[0]][0]]
        for i in range(1,capacity):await self.send(i,'duel_join',code=room.code)
        for i in range(capacity):await self.send(i,'duel_accept',config_revision=1,picture_difficulty='easy')
        await self.send(0,'duel_start')
        return room

    async def test_all_social_games_start_with_two_to_six_players(self):
        for category in sorted(CATEGORIES):
            for capacity in range(2,7):
                with self.subTest(category=category,capacity=capacity):
                    room=await self.create(category,capacity)
                    self.assertEqual(room.phase,'active')
                    for player in range(capacity):
                        self.assertEqual(room.view(player)['party']['category'],category)
                    for peer in self.peers[:capacity]:
                        self.hub.bindings.pop(peer,None)
                    self.hub.rooms.pop(room.code,None)
                    self.hub.subjects.pop(room.code,None)

    async def test_open_heart_full_match_no_duplicate_awards(self):
        room=await self.create('open_heart')
        ids=set()
        for round_index in range(10):
            card=room.core.current['id'];self.assertNotIn(card,ids);ids.add(card)
            actor=int(room.core.actor)
            with self.assertRaises(ValueError):await self.send((actor+1)%3,'duel_party_finish',card_id=card,participated=True)
            await self.send(actor,'duel_party_finish',card_id=card,participated=True)
            saved=room.scores.copy()
            with self.assertRaises(ValueError):await self.send(actor,'duel_party_finish',card_id=card,participated=True)
            self.assertEqual(room.scores,saved)
            if round_index<9:await self.send(0,'duel_party_next',round=round_index+1)
        self.assertTrue(room.match_finished);self.assertEqual(sum(room.scores),100)

    async def test_vote_privacy_majority_and_hidden_performance_prompt(self):
        room=await self.create('act_it')
        card=room.core.current['id']
        self.assertIsNone(room.view(1)['party']['card'])
        self.assertEqual(room.view(1)['party']['card_id'],card)
        self.assertNotIn('votes',room.view(1)['party'])
        with self.assertRaises(ValueError):await self.send(0,'duel_party_vote',card_id=card,choice=True)
        await self.send(1,'duel_party_vote',card_id=card,choice=True)
        self.assertEqual(room.scores,[0,0,0])
        await self.send(2,'duel_party_vote',card_id=card,choice=True)
        self.assertEqual(room.scores,[20,0,0]);self.assertEqual(room.phase,'results')

    async def test_who_all_players_vote_without_self_nomination(self):
        room=await self.create('who_among_us');card=room.core.current['id']
        with self.assertRaises(ValueError):await self.send(0,'duel_party_vote',card_id=card,choice='0')
        for voter,target in [(0,'1'),(1,'0'),(2,'1')]:await self.send(voter,'duel_party_vote',card_id=card,choice=target)
        self.assertEqual(room.scores,[0,10,0])

    async def test_story_commit_is_secret_until_votes_complete(self):
        room=await self.create('truth_or_fiction');card=room.core.current['id']
        with self.assertRaises(ValueError):await self.send(1,'duel_party_vote',card_id=card,choice=True)
        await self.send(0,'duel_party_story',card_id=card,is_true=True)
        self.assertNotIn('story_truth',room.view(1)['party'])
        await self.send(1,'duel_party_vote',card_id=card,choice=True)
        await self.send(2,'duel_party_vote',card_id=card,choice=False)
        self.assertEqual(room.scores,[0,10,0])

    async def test_player_counts_modes_and_game_boundaries(self):
        for count in range(2,7):
            room=SocialRoom(str(count),count,10,self.hub.catalog,'show_skill',self.hub.social_cards)
            self.assertEqual(room.capacity,count);room.begin()
            self.assertEqual(len(room.view(0)['scores']),count)
        room=await self.create('show_skill')
        with self.assertRaises(ValueError):await self.send(0,'duel_guess',guess='not a photo game')
        self.hub.social_requests[self.peers[4]]='open_heart'
        with self.assertRaises(ValueError):await self.send(4,'duel_join',code=room.code)

    async def test_pause_and_private_token_resume_preserve_round(self):
        room=await self.create('open_heart')
        card=room.core.current['id'];token=room.tokens[1]
        await self.hub.disconnect(self.peers[1]);self.assertTrue(room.paused)
        with self.assertRaises(ValueError):await self.send(0,'duel_party_finish',card_id=card,participated=True)
        peer=self.peers[1];_,claims=self.hub.sessions.issue();self.hub.identities[peer]=claims
        # Resume is bound to the original transport subject, not an arbitrary identity.
        self.hub.identities[peer]['sub']=self.hub.subjects[room.code][1]
        await self.send(1,'duel_hello',game_id='party:open_heart')
        await self.send(1,'duel_resume',code=room.code,token=token)
        self.assertFalse(room.paused);self.assertEqual(room.core.current['id'],card)
        self.assertNotEqual(room.tokens[1],token)

    async def test_draft_flag_is_fail_closed(self):
        hub=SocialHub(secrets.token_urlsafe(48),':memory:',False)
        try:
            peer=Peer();_,claims=hub.sessions.issue();hub.identities[peer]=claims
            await hub.handle(peer,{'type':'duel_hello','protocol':3,'game_id':'party:open_heart'})
            self.assertEqual(peer.messages[-1]['party_games'],[])
            with self.assertRaises(ValueError):await hub.handle(peer,{'type':'duel_party_create','protocol':3,'category':'open_heart','players':2,'rounds':10})
        finally:hub.moderation.db.close()

    async def test_expired_resume_and_performance_timeout(self):
        room=await self.create('show_skill')
        room.deadline=0
        self.assertTrue(room.expire());self.assertEqual(room.scores,[0,0,0])
        self.assertFalse(room.expire())
        await self.hub.disconnect(self.peers[1])
        token=room.tokens[1];room.disconnected[1]-=91
        _,claims=self.hub.sessions.issue();claims['sub']=self.hub.subjects[room.code][1]
        self.hub.identities[self.peers[1]]=claims
        await self.send(1,'duel_hello',game_id='party:show_skill')
        with self.assertRaises(ValueError):await self.send(1,'duel_resume',code=room.code,token=token)
        self.assertTrue(room.paused)

    async def test_original_photo_and_quiz_routes_remain_separate(self):
        await self.send(0,'duel_hello')
        await self.send(0,'duel_create',players=2,timer=30,target=1,room_agreement=True,picture_difficulty='easy',picture_category='all')
        photo=self.hub.rooms[self.hub.bindings[self.peers[0]][0]]
        self.assertNotIsInstance(photo,SocialRoom)
        catalog=json.loads((Path(__file__).resolve().parents[1]/'data/guess_picture_302/catalog.json').read_text(encoding='utf-8'))
        original={item['id']:item for item in catalog['items'] if item.get('group')=='original_200'}
        self.assertEqual(len(original),200)
        self.assertTrue(original.keys()<=self.hub.catalog.keys())
        self.assertTrue(all(self.hub.catalog[key]['image']==item['image'] for key,item in original.items()))
        await self.send(0,'duel_leave')
        await self.send(0,'duel_hello',game_id='1')
        capabilities=self.peers[0].messages[-1]
        self.assertEqual(len(capabilities['quiz_games']),9)
        await self.send(0,'duel_quiz_create',game_id='1',players=2,timer=30,rounds=1,difficulty='easy')
        quiz=self.hub.rooms[self.hub.bindings[self.peers[0]][0]]
        self.assertNotIsInstance(quiz,SocialRoom)
        self.assertEqual(quiz.adapter.game_id,'1')

    async def test_real_sockets_six_games_and_authenticated_resume(self):
        async def receive(socket, kind, predicate=lambda value:True):
            for _ in range(30):
                value=json.loads(await asyncio.wait_for(socket.recv(),5))
                if value['type']=='duel_error':self.fail(value['message'])
                if value['type']==kind and predicate(value):return value
            self.fail('Expected state did not arrive')
        async def send(socket,kind,**fields):
            await socket.send(json.dumps({'type':kind,'protocol':3,**fields}))
        async with serve(self.hub.connection,'127.0.0.1',0,process_request=self.hub.http,max_size=8192,compression=None) as service:
            endpoint='ws://127.0.0.1:'+str(service.sockets[0].getsockname()[1])
            for category in ('open_heart','act_it','show_skill','who_among_us','truth_or_fiction','table_flip'):
                sessions=[self.hub.sessions.issue()[0] for _ in range(2)]
                async with connect(endpoint,additional_headers={'Authorization':'Bearer '+sessions[0]}) as a,connect(endpoint,additional_headers={'Authorization':'Bearer '+sessions[1]}) as b:
                    for peer in (a,b):
                        await send(peer,'duel_hello',game_id='party:'+category)
                        capabilities=await receive(peer,'duel_capabilities')
                        self.assertIn(category,capabilities['party_games'])
                    await send(a,'duel_party_create',category=category,players=2,rounds=10)
                    created=await receive(a,'duel_created');code=created['code']
                    await send(b,'duel_join',code=code);joined=await receive(b,'duel_joined')
                    for peer in (a,b):
                        await send(peer,'duel_accept',config_revision=1,picture_difficulty='easy')
                    await receive(a,'duel_state',lambda s:all(s['confirmed']))
                    await send(a,'duel_start')
                    state=await receive(a,'duel_state',lambda s:s['started'])
                    card=state['party']['card_id']
                    if category=='open_heart':await send(a,'duel_party_finish',card_id=card,participated=True)
                    elif category in ('act_it','show_skill'):await send(b,'duel_party_vote',card_id=card,choice=True)
                    elif category=='who_among_us':
                        await send(a,'duel_party_vote',card_id=card,choice='1')
                        await send(b,'duel_party_vote',card_id=card,choice='0')
                    elif category=='truth_or_fiction':
                        await send(a,'duel_party_story',card_id=card,is_true=True)
                        await receive(b,'duel_state',lambda s:s['party'].get('story_committed',False))
                        await send(b,'duel_party_vote',card_id=card,choice=True)
                    else:await send(a,'duel_party_power',card_id=card,target='1')
                    result=await receive(a,'duel_state',lambda s:s['party']['phase']=='results')
                    await b.close()
                    await receive(a,'duel_state',lambda s:s['paused'])
                    async with connect(endpoint,additional_headers={'Authorization':'Bearer '+sessions[1]}) as restored:
                        await send(restored,'duel_hello',game_id='party:'+category)
                        await receive(restored,'duel_capabilities')
                        await send(restored,'duel_resume',code=code,token=joined['token'])
                        resumed=await receive(restored,'duel_resumed')
                        snapshot=await receive(restored,'duel_state',lambda s:not s['paused'])
                        self.assertNotEqual(resumed['token'],joined['token'])
                        self.assertEqual(snapshot['scores'],result['scores'])
                        self.assertEqual(snapshot['party']['round'],1)
                        await send(a,'duel_leave')


class PowerAndCatalogTests(unittest.TestCase):
    def game(self,kind,count=3):
        return PowerMatch(tuple(str(i) for i in range(count)),[{'id':'test_'+kind,'category':'table_flip','power_type':kind,'text_ar':'test'}],10)

    def test_all_power_types_and_target_validation(self):
        for kind in ('swap','bonus','steal','shield','skip','double','gift','self_bonus','choice','reverse'):
            game=self.game(kind);game.draw();game.scores['1']=10
            if kind in ('bonus','steal','skip'):
                with self.assertRaises(ValueError):game.apply('0','0')
            result=game.apply('0','1')
            self.assertEqual(result['round'],1);self.assertEqual(len(set(game.order)),3)
            with self.assertRaises(ValueError):game.apply('0','1')
            if kind=='reverse':self.assertEqual(game.actor,'2')
            if kind=='swap':self.assertEqual(game.actor,'2')
            if kind=='steal':self.assertEqual(game.scores,{'0':5,'1':5,'2':0})
            if kind=='skip':self.assertEqual(game.actor,'2')

    def test_two_offers_cannot_be_replaced_or_forged(self):
        game=self.game('choice');game.cards += [{'id':str(i),'category':'table_flip','power_type':'self_bonus','text_ar':str(i)} for i in range(4)]
        game.current=game.cards[0];game.used.add(game.current['id']);game.apply('0')
        game.draw();offered=[c['id'] for c in game.offered]
        with self.assertRaises(ValueError):game.draw()
        with self.assertRaises(ValueError):game.choose(game.actor,'not offered')
        self.assertEqual([c['id'] for c in game.offered],offered)
        game.choose(game.actor,offered[1]);self.assertEqual(game.current['id'],offered[1])

    def test_shield_double_and_bounded_skipping(self):
        game=self.game('steal');game.scores['1']=9;game.shields['1']=1;game.draw()
        game.apply('0','1');self.assertEqual(game.scores,{'0':0,'1':9,'2':0});self.assertEqual(game.shields['1'],0)
        game=self.game('self_bonus');game.doubles['0']=1;game.draw();game.apply('0')
        self.assertEqual(game.scores['0'],10);self.assertEqual(game.doubles['0'],0)
        game=self.game('reverse');game.skips=dict.fromkeys(game.players,1);game.draw();game.apply('0')
        self.assertEqual(len(set(game.order)),3);self.assertEqual(sum(game.skips.values()),0)

    def test_full_catalog_has_no_duplicate_runtime_ids(self):
        cards=load_social_deck();self.assertEqual(len({c['id'] for c in cards}),len(cards))
        self.assertEqual({c['category'] for c in cards},{'open_heart','act_it','who_among_us','show_skill','truth_or_fiction','table_flip'})
        self.assertGreaterEqual(len(cards),2700)


if __name__=='__main__':unittest.main()
