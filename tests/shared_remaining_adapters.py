import asyncio,secrets,sys,time,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from shared_quiz_local import SharedQuizHub,ProtocolError
class Peer:
 async def send(self,message):pass
class Remaining(unittest.IsolatedAsyncioTestCase):
 async def test_remaining_adapters(self):
  for game in ('4','5','8'):
   h=SharedQuizHub(secrets.token_urlsafe(48),':memory:');a,b=Peer(),Peer()
   async def send(p,kind,**fields):return await h.handle(p,dict(type=kind,protocol=3,**fields))
   try:
    for p in (a,b):h.identities[p]=h.sessions.issue()[1];await send(p,'duel_hello',game_id=game)
    await send(a,'duel_quiz_create',game_id=game,players=2,timer=60,rounds=2 if game=='4' else 1,difficulty='easy');r,_=h.binding(a)
    await send(b,'duel_join',code=r.code)
    for p in (a,b):await send(p,'duel_accept',config_revision=r.config_revision,picture_difficulty='easy')
    await send(a,'duel_start');r.start_clock=time.monotonic()-.1
    if game=='4':
     self.assertEqual(r.queue,h.adapters[game].pool('easy','all')[:2]);self.assertIn('narrative_ar',r.question)
     self.assertEqual(r.question['id'],r.queue[0]['id'])
     for p in (a,b):await send(p,'duel_quiz_answer',question_id=r.question['id'],choice=r.answer)
     await send(a,'duel_quiz_next');self.assertEqual(r.question['id'],r.queue[1]['id'])
    elif game=='5':
     original=next(q for q in h.adapters['5'].questions if q.get('image'))
     q,answer=h.adapters['5'].public(original);self.assertTrue((Path(__file__).resolve().parents[1]/q['image'][6:]).is_file())
     for lang in ('ar','en','tr'):self.assertEqual(q['choices_'+lang][answer],original['choices_'+lang][original['correct']])
    else:
     self.assertEqual(len(r.answer['board']),12);self.assertNotIn('board',r.question)
     self.assertEqual(r.view(1)['quiz']['memory']['revealed'],{})
     with self.assertRaises(ProtocolError):await send(a,'duel_quiz_answer',question_id=r.question['id'],choice=True)
     with self.assertRaises(ProtocolError):await send(a,'duel_quiz_flip',question_id=r.question['id'],index=True)
     first=0;different=next(i for i,c in enumerate(r.answer['board']) if c['name']!=r.answer['board'][0]['name'])
     await send(a,'duel_quiz_flip',question_id=r.question['id'],index=first)
     self.assertEqual(r.view(1)['quiz']['memory']['revealed'],{})
     await send(a,'duel_quiz_flip',question_id=r.question['id'],index=different)
     with self.assertRaises(ProtocolError):await send(a,'duel_quiz_flip',question_id=r.question['id'],index=first)
     self.assertGreater(r.memory[0]['hide_at']-time.monotonic(),1.4)
     r.memory[0]['hide_at']=time.monotonic()-1
     self.assertEqual(r.view(0)['quiz']['memory']['revealed'],{})
     # Reconnect keeps the actual board, moves and private progress.
     board=r.answer['board'];token=r.tokens[1];identity=h.identities[b].copy();await h.disconnect(b)
     c=Peer();h.identities[c]=identity;await send(c,'duel_hello',game_id='8');await send(c,'duel_resume',code=r.code,token=token)
     self.assertEqual(r.answer['board'],board);b=c
     pairs={}
     for i,card in enumerate(board):pairs.setdefault(card['name'],[]).append(i)
     for p in (a,b):
      for indexes in pairs.values():
       for i in indexes:await send(p,'duel_quiz_flip',question_id=r.question['id'],index=i)
     self.assertEqual(r.scores[0],88);self.assertEqual(r.scores[1],90)
     self.assertEqual(r.phase,'finished');self.assertTrue(all(row['correct'] for row in r.results));self.assertEqual(r.view(0)['scores'],r.view(1)['scores'])
    print('REMAINING_ADAPTER_PASS',game)
   finally:h.moderation.db.close()
if __name__=='__main__':unittest.main()
