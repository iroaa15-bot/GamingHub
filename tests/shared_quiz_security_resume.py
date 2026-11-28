import sys,asyncio,secrets,time,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from shared_quiz_local import SharedQuizHub,ProtocolError
class Peer:
 def __init__(self):self.messages=[]
 async def send(self,message):self.messages.append(message)
class QuizBoundaries(unittest.IsolatedAsyncioTestCase):
 async def test_photo_round_break_allows_room_controls(self):
  h=SharedQuizHub(secrets.token_urlsafe(48),':memory:');a,b=Peer(),Peer();peers=[a,b]
  async def action(peer,kind,**fields):return await h.handle(peer,dict(type=kind,protocol=3,**fields))
  try:
   for peer in peers:h.identities[peer]=h.sessions.issue()[1];await action(peer,'duel_hello')
   await action(a,'duel_create',room_agreement=True,manual_rounds=True,players=2,timer=0,target=3,picture_difficulty='easy')
   room,_=h.binding(a);await action(b,'duel_join',code=room.code)
   await action(a,'duel_propose',picture_category='all',primary_mode='mixed')
   for peer in peers:await action(peer,'duel_accept',config_revision=room.config_revision,picture_difficulty='easy')
   await action(a,'duel_start')
   await action(a,'duel_voice_state',enabled=True);await action(b,'duel_voice_state',enabled=True)
   await action(a,'duel_guess',guess='test guess');await action(b,'duel_confirm',correct=True)
   self.assertTrue(room.awaiting_next_round)
   self.assertEqual(room.scores,[1,0])
   await action(a,'duel_sync')
   await action(b,'duel_chat',text='next round')
   self.assertEqual(h.voice[room.code]['enabled'],[True,True])
   with self.assertRaises(ProtocolError):await action(b,'duel_next_round',round=room.round)
   await action(a,'duel_next_round',round=room.round)
   self.assertFalse(room.awaiting_next_round)
   asker=room.current;responder=room.responder
   await action(peers[asker],'duel_guess',guess='second guess')
   await action(peers[responder],'duel_confirm',correct=True)
   self.assertTrue(room.awaiting_next_round)
   code=room.code
   await action(a,'duel_leave')
   self.assertNotIn(code,h.rooms)
  finally:h.moderation.db.close()
 async def test_category_change_keeps_explicit_voice_consents(self):
  h=SharedQuizHub(secrets.token_urlsafe(48),':memory:');a,b=Peer(),Peer()
  async def action(peer,kind,**fields):return await h.handle(peer,dict(type=kind,protocol=3,**fields))
  try:
   for peer in (a,b):h.identities[peer]=h.sessions.issue()[1];await action(peer,'duel_hello',game_id='1')
   await action(a,'duel_quiz_create',game_id='1',players=2,timer=10,rounds=1,difficulty='easy')
   room,_=h.binding(a);await action(b,'duel_join',code=room.code)
   categories=[key for key in h.adapters['1'].categories if h.adapters['1'].pool('easy',key)]
   self.assertTrue(categories)
   await action(a,'duel_quiz_propose',category=categories[0],primary_mode='voice')
   for peer in (a,b):await action(peer,'duel_accept',config_revision=room.config_revision,picture_difficulty='easy')
   await action(a,'duel_voice_state',enabled=True)
   self.assertEqual(h.voice[room.code]['enabled'],[True,False])
   await action(b,'duel_voice_state',enabled=True)
   await action(a,'duel_quiz_propose',category='all',primary_mode='voice')
   self.assertEqual(room.primary_mode,'voice')
   self.assertEqual(h.voice[room.code]['enabled'],[True,True])
  finally:h.moderation.db.close()
 async def test_pending_security_and_resume(self):
  h=SharedQuizHub(secrets.token_urlsafe(48),':memory:');a,b=Peer(),Peer()
  async def action(peer,kind,**fields):return await h.handle(peer,dict(type=kind,protocol=3,**fields))
  try:
   for peer in [a,b]:h.identities[peer]=h.sessions.issue()[1];await action(peer,'duel_hello',game_id='1')
   identity_b=h.identities[b].copy()
   await action(a,'duel_quiz_create',game_id='1',players=2,timer=10,rounds=2,difficulty='easy')
   room,_=h.binding(a);await action(b,'duel_join',code=room.code)
   for peer in [a,b]:await action(peer,'duel_accept',config_revision=room.config_revision,picture_difficulty='easy')
   await action(a,'duel_start');old_question=room.question['id']
   with self.assertRaises(ProtocolError):await action(a,'duel_quiz_answer',question_id=old_question,choice=room.answer)
   room.start_clock=time.monotonic()-.1;room.deadline=time.monotonic()+9.9
   for bad in [True,-1,6,0.5]:
    with self.assertRaises(ProtocolError):await action(a,'duel_quiz_answer',question_id=old_question,choice=bad)
   await action(a,'duel_quiz_answer',question_id=old_question,choice=room.answer)
   with self.assertRaises(ProtocolError):await action(a,'duel_quiz_answer',question_id=old_question,choice=room.answer)
   self.assertNotIn('correct_index',room.view(1)['quiz'])
   await h.disconnect(b);remaining=room.remaining;start_before=room.start_clock;audio_before=room.audio_at;token=room.tokens[1]
   with self.assertRaises(ProtocolError):await action(a,'duel_quiz_answer',question_id=old_question,choice=room.answer)
   await asyncio.sleep(.05)
   restored=Peer();h.identities[restored]=identity_b
   await action(restored,'duel_hello',game_id='1');await action(restored,'duel_resume',code=room.code,token=token)
   self.assertGreater(room.start_clock-start_before,.04)
   self.assertGreater(room.audio_at-audio_before,40)
   self.assertAlmostEqual(room.deadline-time.monotonic(),remaining,delta=.1)
   self.assertNotEqual(room.tokens[1],token)
   await action(restored,'duel_quiz_answer',question_id=old_question,choice=room.answer)
   self.assertEqual(room.phase,'results')
   with self.assertRaises(ProtocolError):await action(restored,'duel_quiz_next')
   await action(a,'duel_quiz_next');self.assertNotEqual(room.question['id'],old_question)
   with self.assertRaises(ProtocolError):await action(a,'duel_quiz_answer',question_id=old_question,choice=room.answer)
   stranger=Peer();h.identities[stranger]=h.sessions.issue()[1];await action(stranger,'duel_hello',game_id='6')
   with self.assertRaises(ProtocolError):await action(stranger,'duel_join',code=room.code)
   room.deadline=time.monotonic()-1;await action(a,'duel_sync')
   self.assertTrue(room.match_finished);self.assertFalse(room.closed)
   self.assertIsNotNone(room.view(0)['quiz']['correct_index'])
   self.assertTrue(h.voice_state(room,0)['available'])
   self.assertEqual(room.results[0]['points'],0)
   await action(a,'duel_leave');self.assertNotIn(room.code,h.rooms)
  finally:h.moderation.db.close()
if __name__=='__main__':unittest.main()
