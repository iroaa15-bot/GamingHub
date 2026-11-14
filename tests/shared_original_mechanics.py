import asyncio,secrets,sys,time,unittest,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from shared_quiz_local import SharedQuizHub,ProtocolError
from shared_game_adapters import normalize
class Peer:
 async def send(self,message):pass
class Mechanics(unittest.IsolatedAsyncioTestCase):
 async def test_original_mechanics(self):
  for game,mode in [('2','write'),('7','identity'),('9','order')]:
   h=SharedQuizHub(secrets.token_urlsafe(48),':memory:');a,b=Peer(),Peer()
   async def send(p,kind,**fields):return await h.handle(p,dict(type=kind,protocol=3,**fields))
   try:
    for p in (a,b):h.identities[p]=h.sessions.issue()[1];await send(p,'duel_hello',game_id=game)
    await send(a,'duel_quiz_create',game_id=game,players=2,timer=30,rounds=1,difficulty='easy');r,_=h.binding(a)
    await send(b,'duel_join',code=r.code)
    for p in (a,b):await send(p,'duel_accept',config_revision=r.config_revision,picture_difficulty='easy')
    await send(a,'duel_start')
    # Deterministic original question fixture, not fabricated content or a passed random choice.
    r.queue=[next(q for q in h.adapters[game].pool('easy','all') if q.get('mode')==mode)];r.index=-1;r.begin_question();r.start_clock=time.monotonic()-.1
    q=r.question;self.assertEqual(q['mode'],mode);self.assertNotIn('aliases',json.dumps(q));self.assertNotIn('correct_index',r.view(0)['quiz'])
    if mode=='identity':
     before=r.view(1)['quiz']['clues'];await send(a,'duel_quiz_clue',question_id=q['id'])
     self.assertEqual(before,r.view(1)['quiz']['clues']);self.assertEqual(r.clues_used,{0:1})
    if mode=='order':
     with self.assertRaises(ProtocolError):await send(a,'duel_quiz_answer',question_id=q['id'],sequence=[0]*len(q['steps_ar']))
     right={'sequence':r.answer['sequence']};wrong={'sequence':list(reversed(r.answer['sequence']))}
    else:
     with self.assertRaises(ProtocolError):await send(a,'duel_quiz_answer',question_id=q['id'],text=' '*10)
     right={'text':r.queue[0]['answers_tr'][0]};wrong={'text':'definitely incorrect'}
     for lang in ('ar','en','tr'):
      self.assertTrue(r.adapter.correct(normalize(r.queue[0]['answers_'+lang][0]),r.answer))
    await send(a,'duel_quiz_answer',question_id=q['id'],**right)
    with self.assertRaises(ProtocolError):await send(a,'duel_quiz_answer',question_id=q['id'],**right)
    await send(b,'duel_quiz_answer',question_id=q['id'],**wrong)
    self.assertEqual(r.phase,'finished');self.assertGreater(r.scores[0],0);self.assertEqual(r.scores[1],0)
    self.assertEqual(r.view(0)['scores'],r.view(1)['scores'])
    print('ORIGINAL_MECHANIC_PASS',game,mode,r.scores)
   finally:h.moderation.db.close()
if __name__=='__main__':unittest.main()
