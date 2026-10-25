import json,unittest,time
from server.party_room_engine import new_room,PartyError,ROUND_SEQUENCE
from server.party_challenges import drawing
class PartyCompleteTests(unittest.TestCase):
 def room(self):
  r,_=new_room('p0','Player 0')
  for i in range(1,6):r.join('p'+str(i),'Player '+str(i))
  for p in r.members:r.ready(p,True)
  r.start('p0');return r
 def test_six_players_all_eight_games_fifteen_rounds_scoring(self):
  r=self.room();seen=set()
  for index,game in enumerate(ROUND_SEQUENCE):
   seen.add(game)
   for i,p in enumerate(r.members):
    answer={'pass_the_bomb':['banana','bear','bread','bee','ball','boat'][i], 'whos_most_likely':'p1','odd_one_out':'B','crazy_emoji':'الملك الأسد','fake_it':'كوكب '+str(i),'truth_or_dare':'truth','draw_disaster':json.dumps([[[0.1,0.1],[0.9,0.9]]]),'secret_mission':'done'}[game]
    r.submit(p,answer,f'{index}-{p}')
    if game=='truth_or_dare':r.complete(p)
   r.reveal('p0')
   if r.phase=='voting':
    for p in r.members:
     options=r.view(p)['reveal']['options']
     self.assertTrue(all(r.option_owners[k]!=p for k in options))
     choice=next((key for key in options if r.option_owners[key]=='truth'),next(iter(options)))
     r.vote(p,choice)
   if game in ('truth_or_dare','secret_mission'):
    for p in r.members:r.approve('p0',p)
   self.assertEqual(r.phase,'reveal')
   r.next_round('p0')
  self.assertEqual(len(seen),8);self.assertEqual(r.phase,'results')
  self.assertTrue(all(score>0 for score in r.scores.values()))
 def test_anonymous_bluffs_and_private_missions(self):
  r=self.room();r.round_index=4
  r.submit('p0','المريخ','a');r.submit('p1','زحل','b');r.reveal('p0')
  state=r.view('p0')
  self.assertNotIn('answers',state['reveal'])
  self.assertNotIn('truth',state['reveal']['options'])
  self.assertNotIn('المريخ',state['reveal']['options'].values())
  with self.assertRaises(PartyError):r.vote('p0',next(k for k,p in r.option_owners.items() if p=='p0'))
  r=self.room();r.round_index=7
  self.assertNotIn('private_task',r.snapshot());self.assertIn('private_task',r.view('p0'))
  self.assertNotEqual(r.view('p0')['private_task'],r.view('p1')['private_task'])
 def test_drawing_validation_review_and_timeout(self):
  for value in ('[]','[[[2,0],[0,0]]]','[[[true,0],[0,0]]]'):
   with self.assertRaises(ValueError):drawing(value)
  r=self.room()
  with self.assertRaises(PartyError):r.submit('p1','banana','a')
  r.deadline=time.monotonic()-1;r.tick();self.assertEqual(r.phase,'reveal')
  r=self.room();r.round_index=7;r.submit('p1','done','a');r.reveal('p0')
  with self.assertRaises(PartyError):r.approve('p1','p1')
  r.approve('p0','p1')
  with self.assertRaises(PartyError):r.approve('p0','p1')
if __name__=='__main__':unittest.main()
