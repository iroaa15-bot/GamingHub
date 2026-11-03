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
