import unittest
from photo_match_protocol import PhotoMatch, MatchError

class PhotoMatchTests(unittest.TestCase):
    def test_settings(self):
        with self.assertRaises(MatchError):
            PhotoMatch(("a","b"), timer=17)
    def test_text_tap_and_reply(self):
        m = PhotoMatch(("a","b"))
        self.assertEqual(m.ask_text("a","هل هو حيوان؟")["mode"], "text")
        self.assertTrue(m.ask_tap("a","animal",{"animal":True})["answer"])
        with self.assertRaises(MatchError):
            m.ask_tap("a","unknown",{})
        self.assertTrue(m.reply("b",True)["answer"])
        with self.assertRaises(MatchError):
            m.reply("a",True)
    def test_confirmation_only_opponent(self):
        m = PhotoMatch(("a","b"), target=3, reward=3)
        m.propose_guess("a","cat")
        with self.assertRaises(MatchError):
            m.confirm_guess("a",True)
        result=m.confirm_guess("b",True)
        self.assertEqual(result[-1]["type"],"photo_finished")
        self.assertEqual(m.scores,[3,0])
    def test_wrong_guess_passes(self):
        m=PhotoMatch(("a","b"))
        m.propose_guess("a")
        m.confirm_guess("b",False)
        self.assertEqual(m.current,1)
        self.assertEqual(m.scores,[0,0])
    def test_unlimited_timer(self):
        m=PhotoMatch(("a","b"),timer=0)
        m.turn_started -= 1000
        self.assertIsNone(m.expire_turn())

if __name__ == "__main__":
    unittest.main()
