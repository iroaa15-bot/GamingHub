"""Run: python -m unittest server.test_party_room_engine"""
import unittest
from server.party_room_engine import new_room, PartyError, ROUND_SEQUENCE


class PartyRoomEngineTests(unittest.TestCase):
    def setUp(self):
        self.room, self.host_token = new_room("host", "Host")
        self.guest_token = self.room.join("guest", "Guest")

    def test_six_player_cap(self):
        for i in range(4):
            self.room.join(f"p{i}", f"Player {i}")
        with self.assertRaisesRegex(PartyError, "room_full"):
            self.room.join("extra", "Extra")

    def test_fifteen_rounds_and_idempotent_submit(self):
        self.room.ready("host", True)
        self.room.ready("guest", True)
        self.room.start("host")
        self.assertEqual(len(ROUND_SEQUENCE), 15)
        first = self.room.submit("guest", "answer", "req1")
        self.assertEqual(first, self.room.submit("guest", "changed", "req1"))
        for _ in range(15):
            self.room.reveal("host")
            self.room.next_round("host")
        self.assertEqual(self.room.phase, "results")
        self.assertEqual(self.room.round_index, 15)

    def test_game_specific_validation(self):
        self.room.ready("host", True)
        self.room.ready("guest", True)
        self.room.start("host")
        with self.assertRaisesRegex(PartyError, "one_word_only"):
            self.room.submit("guest", "two words", "bad")
        self.room.submit("guest", "banana", "good")
        self.room.reveal("host")
        self.room.next_round("host")
        with self.assertRaisesRegex(PartyError, "vote_for_room_member_only"):
            self.room.submit("guest", "outsider", "bad2")
        self.room.submit("guest", "host", "good2")

    def test_vote_reveal_awards_points_once(self):
        self.room.ready("host", True)
        self.room.ready("guest", True)
        self.room.start("host")
        self.room.reveal("host")
        self.room.next_round("host")
        self.room.submit("host", "guest", "vote-host")
        self.room.submit("guest", "guest", "vote-guest")
        revealed = self.room.reveal("host")
        self.assertEqual(revealed["reveal"]["awarded"], {"guest": 1})
        self.assertEqual(revealed["scores"]["guest"], 1)
        with self.assertRaisesRegex(PartyError, "round_not_active"):
            self.room.reveal("host")
        self.room.next_round("host")
        self.assertEqual(self.room.scores["guest"], 1)

    def test_unverified_game_has_no_fabricated_points(self):
        self.room.ready("host", True)
        self.room.ready("guest", True)
        self.room.start("host")
        self.room.submit("guest", "banana", "word")
        revealed = self.room.reveal("host")
        self.assertTrue(revealed["reveal"]["scoring_pending"])
        self.assertEqual(revealed["reveal"]["awarded"], {})
        self.assertEqual(revealed["scores"]["guest"], 0)

    def test_completed_match_snapshot_has_no_game(self):
        self.room.ready("host", True)
        self.room.ready("guest", True)
        self.room.start("host")
        for _ in range(15):
            self.room.reveal("host")
            self.room.next_round("host")
        result = self.room.snapshot()
        self.assertEqual(result["phase"], "results")
        self.assertIsNone(result["game"])
        self.assertIsNone(result["round_rule"])

    def test_only_host_can_advance(self):
        self.room.ready("host", True)
        self.room.ready("guest", True)
        with self.assertRaisesRegex(PartyError, "host_only"):
            self.room.start("guest")

    def test_reconnect_preserves_round(self):
        self.room.ready("host", True)
        self.room.ready("guest", True)
        self.room.start("host")
        self.room.disconnect("guest")
        with self.assertRaisesRegex(PartyError, "invalid_resume_token"):
            self.room.reconnect("guest", "wrong")
        state = self.room.reconnect("guest", self.guest_token)
        self.assertEqual(state["round_index"], 0)
        self.assertEqual(state["phase"], "active")


if __name__ == "__main__":
    unittest.main()
