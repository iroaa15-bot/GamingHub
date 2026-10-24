import json
from pathlib import Path
import unittest
from photo_match_protocol import MatchError
from photo_room_service import PhotoRoom

class PhotoRoomTests(unittest.TestCase):
    def setUp(self):self.room=PhotoRoom(('a','b'))
    def test_secret_not_in_own_snapshot(self):
        for i,p in enumerate(('a','b')):
            snapshot=self.room.view(p)
            self.assertNotIn(self.room.secret_ids[i],json.dumps(snapshot))
            self.assertEqual(snapshot['visible_opponent_image']['id'],self.room.secret_ids[1-i])
    def test_forged_facts_ignored_and_self_confirmation_rejected(self):
        r=self.room
        correct=r.catalog[r.secret_ids[0]]['facts']['living']
        result=r.handle('a',{'type':'photo_tap','question_id':'living','facts':{'living':not correct},'player':'b'})
        self.assertEqual(result['answer'],correct)
        r.handle('a',{'type':'photo_guess','guess':'test'})
        with self.assertRaises(MatchError):r.handle('a',{'type':'photo_confirm','correct':True})
        r.handle('b',{'type':'photo_confirm','correct':True})
        self.assertEqual(r.match.scores,[1,0])
    def test_resume_token_rotation_and_leave(self):
        r=self.room;old=r.tokens['a'];r.disconnect('a')
        with self.assertRaises(MatchError):r.handle('b',{'type':'photo_pass'})
        new,state=r.resume(old)
        self.assertNotEqual(old,new)
        with self.assertRaises(MatchError):r.authenticate(old)
        self.assertEqual(r.authenticate(new),'a')
        r.leave('b')
        with self.assertRaises(MatchError):r.handle('a',{'type':'photo_pass'})
    def test_repeated_sessions(self):
        for _ in range(20):
            r=PhotoRoom(('a','b'),target=3,reward=3)
            for _ in range(4):
                p=r.match.players[r.match.current]
                r.handle(p,{'type':'photo_pass'})
            p=r.match.players[r.match.current];other=r.match.players[1-r.match.current]
            r.handle(p,{'type':'photo_guess'})
            r.handle(other,{'type':'photo_confirm','correct':True})
            self.assertTrue(r.match.finished)
    def test_exact_core_assets(self):
        r=self.room;root=Path(__file__).resolve().parents[1]
        self.assertEqual(len(r.catalog),200)
        paths=[x['image'] for x in r.catalog.values()]
        self.assertEqual(len(set(paths)),200)
        for x in r.catalog.values():
            self.assertTrue((root/x['image'].removeprefix('res://')).is_file())
            self.assertTrue(all(type(v) is bool for v in x['facts'].values()))
            self.assertTrue(x['ar'] and x['en'] and x['tr'])

if __name__=='__main__':unittest.main()
