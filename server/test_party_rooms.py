import unittest
from party_rooms import PartyRoom

CARDS = [{"id": "heart", "category": "open_heart"},
         {"id": "act", "category": "act_it"},
         {"id": "who", "category": "who_among_us"},
         {"id": "story", "category": "truth_or_fiction"}]

class PartyRoomTests(unittest.TestCase):
    def setUp(self):
        self.room = PartyRoom(("a", "b", "c"), CARDS)

    def test_player_limits(self):
        with self.assertRaises(ValueError):
            PartyRoom(("a",), CARDS)
        with self.assertRaises(ValueError):
            PartyRoom(("a", "a"), CARDS)
        with self.assertRaises(ValueError):
            PartyRoom(tuple("abcdefg"), CARDS)

    def test_no_repeats_and_turns(self):
        self.room.draw("open_heart")
        with self.assertRaises(ValueError):
            self.room.draw()
        self.assertEqual(self.room.finish()["awards"], {"a": 10})
        with self.assertRaises(ValueError):
            self.room.draw("open_heart")
        self.assertEqual(self.room.actor, "b")

    def test_vote_restrictions(self):
        self.room.draw("who_among_us")
        with self.assertRaises(ValueError):
            self.room.vote("a", "a")
        with self.assertRaises(ValueError):
            self.room.vote("c", "c")
        self.room.vote("a" if self.room.actor != "a" else "b", "c")
        with self.assertRaises(ValueError):
            self.room.vote("b", "c")

    def test_full_electorate_and_one_award(self):
        self.room.draw("who_among_us")
        self.room.vote("a","b")
        self.room.vote("b","c")
        with self.assertRaises(ValueError):self.room.finish()
        self.room.vote("c","b")
        self.assertEqual(self.room.finish()["awards"],{"b":10})
        with self.assertRaises(ValueError):self.room.finish()
        self.assertEqual(self.room.scores["b"],10)

    def test_performance_cannot_finish_after_one_vote(self):
        self.room.draw("act_it")
        with self.assertRaises(ValueError):self.room.vote("a",True)
        self.room.vote("b",True)
        with self.assertRaises(ValueError):self.room.finish()
        self.room.vote("c",False)
        self.assertEqual(self.room.finish()["awards"],{})

    def test_story_secret(self):
        self.room.draw("truth_or_fiction")
        self.room.commit_story("a", True)
        self.assertNotIn("story_truth", self.room.public_state("b"))
        self.room.vote("b", False)
        self.room.vote("c", False)
        self.assertEqual(self.room.finish()["awards"], {"a": 10})

    def test_votes_not_public_before_reveal(self):
        self.room.draw("act_it")
        self.room.vote("b", True)
        state = self.room.public_state("c")
        self.assertNotIn("votes", state)
        self.assertEqual(state["voted_players"], ["b"])

if __name__ == "__main__":
    unittest.main()
