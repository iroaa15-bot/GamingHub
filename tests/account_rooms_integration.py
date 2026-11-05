"""Exercise real v3 room completion, guest fallback, resume and reward scheduling."""
import asyncio,sys,time,unittest,os
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from shared_quiz_local import SharedQuizHub,QuizRoom
from identity_backend.gameplay_content import question_projection

class Accounts(unittest.IsolatedAsyncioTestCase):
 async def asyncSetUp(self):
  self.hub=SharedQuizHub('test-only-'+'a'*48,':memory:')
  self.messages=[];self.awards=[]
  async def send(ws,msg):self.messages.append((ws,msg))
  self.hub.send=send
  self.hub.persist_award=lambda intent:self.awards.append(intent)
  self.a=object();self.b=object()
  for ws in (self.a,self.b):self.hub.identities[ws]={'sub':str(id(ws)),'exp':time.time()+500}
 async def asyncTearDown(self):
  if self.hub.award_jobs:await asyncio.gather(*self.hub.award_jobs.values())
  self.hub.moderation.db.close()
 async def test_authoritative_quiz_result_is_awarded_once(self):
  adapter=self.hub.adapters['3'];room=QuizRoom('123456',2,0,1,self.hub.catalog,adapter,'easy')
  room.peers=[self.a,self.b];room.joined=2;room.started=True
  room.queue=adapter.pool('easy','all')[:1];room.begin_question()
  room.answers={0:(room.answer,100),1:((room.answer+1)%4,200)}
  self.hub.account_connections[self.a]='verified-account'
  room.finish_question()
  await self.hub.publish(room);await self.hub.publish(room)
  await asyncio.sleep(.05)
  self.assertEqual(self.awards,[(room.match_id,'verified-account')])
  self.hub.account_connections[self.a]='different-account'
  await self.hub.publish(room);await asyncio.sleep(.05)
  self.assertEqual(len(self.awards),1)
 async def test_mixed_question_turns_and_final_guess_have_server_role_checks(self):
  from photo_duel_extension import ProtocolError
  self.hub.membership_voice=True
  await self.hub.handle(self.a,{'type':'duel_create','protocol':3,'players':2,'timer':30,'target':10,'room_agreement':True,'picture_difficulty':'easy'})
  code=self.hub.bindings[self.a][0];room=self.hub.rooms[code]
  await self.hub.handle(self.b,{'type':'duel_join','protocol':3,'code':code})
  await self.hub.handle(self.a,{'type':'duel_propose','protocol':3,'picture_category':'all','primary_mode':'mixed'})
  for ws in (self.a,self.b):
   await self.hub.handle(ws,{'type':'duel_accept','protocol':3,'config_revision':room.config_revision,'picture_difficulty':'easy'})
  await self.hub.handle(self.a,{'type':'duel_start','protocol':3})
  async def act(ws,kind,**data):await self.hub.handle(ws,{'type':kind,'protocol':3,**data})
  with self.assertRaises(ProtocolError):await act(self.b,'duel_question',text='Unauthorized turn')
  await act(self.a,'duel_question',text='Is this an animal?')
  with self.assertRaises(ProtocolError):await act(self.a,'duel_voice_question')
  with self.assertRaises(ProtocolError):await act(self.a,'duel_reply',answer=True)
  await act(self.b,'duel_reply',answer=True)
  self.assertEqual(room.scores,[0,0]);self.assertEqual(room.current,1)
  await act(self.b,'duel_voice_question')
  with self.assertRaises(ProtocolError):await act(self.b,'duel_question',text='Concurrent question')
  await act(self.a,'duel_reply',answer=False)
  self.assertEqual(room.current,0)
  await act(self.a,'duel_guess',guess='Final guess')
  with self.assertRaises(ProtocolError):await act(self.b,'duel_reply',answer=True)
  self.assertEqual(room.scores,[0,0])
  await act(self.b,'duel_confirm',correct=True)
  self.assertEqual(room.scores,[1,0])
  with self.assertRaises(ProtocolError):await act(self.b,'duel_confirm',correct=True)
 async def test_exact_quiz_ties_share_round_points_without_arbitrary_match_winner(self):
  adapter=self.hub.adapters['3'];room=QuizRoom('345678',2,30,1,self.hub.catalog,adapter,'easy')
  room.peers=[self.a,self.b];room.joined=2;room.started=True
  room.queue=adapter.pool('easy','all')[:1];room.begin_question()
  room.answers={0:(room.answer,100),1:(room.answer,100)}
  room.finish_question()
  self.assertEqual(room.scores[0],room.scores[1]);self.assertEqual(room.winner,-1)
  self.hub.account_connections[self.a]='account-a';self.hub.account_connections[self.b]='account-b'
  self.assertIsNone(self.hub.reward_intent(room))
 async def test_duplicate_answers_and_client_elapsed_times_cannot_change_results(self):
  from photo_duel_extension import ProtocolError
  adapter=self.hub.adapters['3'];room=QuizRoom('456789',2,30,1,self.hub.catalog,adapter,'easy')
  room.peers=[self.a,self.b];room.joined=2;room.started=True
  room.queue=adapter.pool('easy','all')[:1];room.begin_question();room.start_clock=time.monotonic()-.2
  self.hub.rooms[room.code]=room;self.hub.bindings[self.a]=(room.code,0);self.hub.bindings[self.b]=(room.code,1)
  answer={'type':'duel_quiz_answer','protocol':3,'question_id':room.question['id'],'choice':room.answer,'elapsed_ms':-999999}
  await self.hub.handle(self.a,answer)
  first=room.answers[0]
  self.assertGreaterEqual(first[1],190)
  with self.assertRaises(ProtocolError):await self.hub.handle(self.a,{**answer,'choice':(room.answer+1)%4})
  self.assertEqual(room.answers[0],first)
 async def test_authenticated_resume_replaces_half_open_socket_and_rejects_replay(self):
  from photo_duel_extension import ProtocolError
  for ws in (self.a,self.b):await self.hub.handle(ws,{'type':'duel_hello','protocol':3,'game_id':'3'})
  await self.hub.handle(self.a,{'type':'duel_quiz_create','protocol':3,'game_id':'3','players':2,'timer':0,'rounds':1,'difficulty':'easy'})
  code=self.hub.bindings[self.a][0];room=self.hub.rooms[code]
  await self.hub.handle(self.b,{'type':'duel_join','protocol':3,'code':code})
  old_token=room.tokens[0]
  replacement=object()
  self.hub.identities[replacement]={'sub':'wrong-identity','exp':time.time()+500}
  resume={'type':'duel_resume','protocol':3,'code':code,'token':old_token}
  with self.assertRaises(ProtocolError):await self.hub.handle(replacement,resume)
  self.assertIs(room.peers[0],self.a)
  self.hub.identities[replacement]={'sub':self.hub.identities[self.a]['sub'],'exp':time.time()+500}
  await self.hub.handle(replacement,resume)
  self.assertNotIn(self.a,self.hub.bindings)
  self.assertIs(room.peers[0],replacement)
  self.assertNotEqual(room.tokens[0],old_token)
  await self.hub.disconnect(self.a)
  self.assertIs(room.peers[0],replacement)
  replay=object();self.hub.identities[replay]=self.hub.identities[replacement].copy()
  with self.assertRaises(ProtocolError):await self.hub.handle(replay,resume)
  self.assertIs(room.peers[0],replacement)
 async def test_guests_ties_and_disconnected_winner_never_receive_account_awards(self):
  for tied,disconnected in ((False,False),(True,False),(False,True)):
   room=QuizRoom('123457',2,0,1,self.hub.catalog,self.hub.adapters['3'],'easy')
   room.started=True;room.match_finished=True;room.scores=[1000,1000 if tied else 0];room.peers=[None if disconnected else self.a,self.b]
   if tied or disconnected:self.hub.account_connections[self.a]='verified-account'
   await self.hub.publish(room)
  await asyncio.sleep(.05);self.assertEqual(self.awards,[])
 async def test_failed_rebind_clears_identity_and_gameplay_survives(self):
  self.hub.account_connections[self.a]='old-account'
  await self.hub.handle(self.a,{'type':'duel_auth_bind','protocol':3,'access_token':'invalid'})
  self.assertNotIn(self.a,self.hub.account_connections)
  self.assertEqual(self.messages[-1][1],{'type':'duel_auth_bound','ok':False})
  await self.hub.handle(self.a,{'type':'duel_hello','protocol':3,'game_id':'3'})
  await self.hub.handle(self.a,{'type':'duel_quiz_create','protocol':3,'game_id':'3','players':2,'timer':0,'rounds':1,'difficulty':'easy'})
  self.assertIn(self.a,self.hub.bindings)

class Content(unittest.TestCase):
 def test_only_well_formed_localized_game_questions_enter_gameplay(self):
  payload={'game_id':'5','ar':'سؤال','en':'Question','choices_ar':['أ','ب','ج','د'],'choices_en':['A','B','C','D'],'correct':2,'admin_key':'must-not-escape','image':'../../private'}
  q=question_projection('test','question',payload)
  self.assertEqual(q['correct'],2);self.assertNotIn('admin_key',q);self.assertNotIn('image',q)
  self.assertIsNone(question_projection('test','sound',payload))
  self.assertIsNone(question_projection('test','question',{**payload,'correct':True}))
  self.assertIsNone(question_projection('test','question',{**payload,'choices_en':['A']*4}))

if __name__=='__main__':unittest.main()
