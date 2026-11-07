import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'server'))
import duel_questions as questions
from photo_duel_extension import Room, ProtocolError
from photo_duel_agreement_local import AgreementHub

class Context(unittest.TestCase):
    def test_single_remaining_candidate_keeps_unasked_followups(self):
        catalog = {name: {'name':name, 'image':name,
                   'facts':{'edible':name != 'Lion'}} for name in ['Orange','Lion']}
        questions.enrich(catalog, {name:{'category':'fruits' if name=='Orange' else 'animals'} for name in catalog})
        room = Room('123456',2,0,3,catalog)
        room.images = ['Orange','Lion']
        questions.remember(room,0,{'question_id':'category_fruits'},True)
        for key in ['fruit_citrus','fruit_bunch','fruit_hard_shell','fruit_stone','edible']:
            self.assertIn(key, questions.available(room,0))
            questions.remember(room,0,{'question_id':key},catalog['Orange']['facts'][key])
            self.assertNotIn(key, questions.available(room,0))
        self.assertIsNone(room.pending)
        self.assertFalse(room.closed)
        self.assertEqual(room.scores,[0,0])

    def test_evidence_filters_questions_without_reading_hidden_answer(self):
        catalog = {name: {'name':name, 'image':name, 'facts':{}} for name in ['Apple','Banana','Orange','Lion']}
        filters = {name:{'category':'animals' if name=='Lion' else 'fruits'} for name in catalog}
        questions.enrich(catalog, filters)
        room = Room('123456',2,0,3,catalog)
        room.images = ['Apple','Lion']
        initial = questions.available(room,0)
        room.images[0] = 'Banana'
        self.assertEqual(initial, questions.available(room,0))
        questions.remember(room,0,{'question_id':'category_fruits','text':'هل هي فاكهة؟'},True)
        remaining = questions.available(room,0)
        self.assertNotIn('category_fruits',remaining)
        self.assertNotIn('category_animals',remaining)
        self.assertIn('fruit_citrus',remaining)
        self.assertIn(questions.normalize('هل هي فاكهة؟'),questions.state(room,0)['texts'])
        self.assertIn('category_fruits',questions.available(room,1))
        room.images[0]='Orange'
        self.assertIn('category_fruits',questions.available(room,0))

class Peer:
    async def send(self,value): pass

class NetworkBoundary(unittest.IsolatedAsyncioTestCase):
    async def test_manual_next_round_scores_once_and_never_reuses_a_picture(self):
        hub=AgreementHub(); a=Peer(); b=Peer()
        async def action(peer, kind, **fields):
            return await hub.handle(peer,dict(type=kind,protocol=3,**fields))
        await action(a,'duel_create',room_agreement=True,manual_rounds=True,picture_difficulty='easy',players=2,target=3)
        room,_=hub.binding(a)
        await action(b,'duel_join',code=room.code)
        for peer in [a,b]:
            await action(peer,'duel_accept',config_revision=room.config_revision,picture_difficulty='easy')
        await action(a,'duel_start')
        original=room.images.copy()
        await action(a,'duel_guess',guess='test')
        await action(b,'duel_confirm',correct=True)
        self.assertEqual(room.scores,[1,0])
        self.assertTrue(room.awaiting_next_round)
        self.assertEqual(room.images,original)
        with self.assertRaises(ProtocolError):await action(b,'duel_confirm',correct=True)
        with self.assertRaises(ProtocolError):await action(b,'duel_next_round',round=1)
        await action(a,'duel_next_round',round=1)
        self.assertNotIn(room.images[0],original)
        self.assertFalse(room.awaiting_next_round)
        self.assertEqual(room.scores,[1,0])
        self.assertEqual(room.current,1)
        with self.assertRaises(ProtocolError):await action(a,'duel_next_round',round=1)

    async def test_repeated_question_rejected_after_turn_and_resume(self):
        hub=AgreementHub(); a=Peer(); b=Peer()
        async def action(peer, kind, **fields):
            return await hub.handle(peer,dict(type=kind,protocol=3,**fields))
        await action(a,'duel_create',room_agreement=True,picture_difficulty='easy',players=2)
        room,_=hub.binding(a)
        await action(b,'duel_join',code=room.code)
        for peer in [a,b]:
            await action(peer,'duel_accept',config_revision=room.config_revision,picture_difficulty='easy')
        await action(a,'duel_start')
        key=questions.available(room,0)[0]
        await action(a,'duel_preset',question_id=key)
        await action(b,'duel_reply',answer=room.catalog[room.images[0]]['facts'][key])
        await action(b,'duel_pass')
        with self.assertRaises(ProtocolError): await action(a,'duel_preset',question_id=key)
        self.assertNotIn(key,room.view(0)['preset_questions'])
        await hub.disconnect(b)
        replacement=Peer()
        await action(replacement,'duel_resume',code=room.code,token=room.tokens[1])
        self.assertNotIn(key,room.view(0)['preset_questions'])

if __name__=='__main__': unittest.main()
