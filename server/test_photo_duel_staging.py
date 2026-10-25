"""Local-only integration checks for the isolated Photo Duel WebSocket hub.

Run from repository root:
    python -m unittest discover -s server -p test_photo_duel_staging.py -v
No production server, GitHub Actions, network port, or Android required.
"""
import asyncio
import base64
import json
import unittest

from photo_duel_staging import StagingHub
from photo_match_protocol import MatchError


class FakeSocket:
    def __init__(self):
        self.messages = []

    async def send(self, value):
        self.messages.append(json.loads(value))

    def last(self, kind):
        return next(m for m in reversed(self.messages) if m["type"] == kind)


class StagingHubTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.hub = StagingHub()
        self.a, self.b, self.outsider = FakeSocket(), FakeSocket(), FakeSocket()
        await self.hub.handle(self.a, {"type": "photo_create", "target": 3, "timer": 0, "reward": 1})
        self.code = self.a.last("photo_created")["code"]
        self.token_a = self.a.last("photo_created")["token"]

    async def join(self):
        await self.hub.handle(self.b, {"type": "photo_join", "code": self.code})
        self.token_b = self.b.last("photo_joined")["token"]

    async def test_create_join_per_player_hidden_image(self):
        await self.join()
        a_state = self.a.last("photo_state")
        b_state = self.b.last("photo_state")
        self.assertNotEqual(a_state["visible_opponent_image"]["id"], b_state["visible_opponent_image"]["id"])
        self.assertEqual(a_state["player"], 0)
        self.assertEqual(b_state["player"], 1)
        self.assertNotIn("token", a_state)
        self.assertNotIn("token", b_state)

    async def test_unauthorized_and_spoofed_player(self):
        await self.join()
        with self.assertRaises(MatchError):
            await self.hub.handle(self.outsider, {"type": "photo_sync", "code": self.code})
        with self.assertRaises(MatchError):
            await self.hub.handle(self.b, {"type": "photo_pass", "player": self.hub.sockets[self.a][1]})
        await self.hub.handle(self.a, {"type": "photo_pass", "player": "forged"})
        self.assertEqual(self.b.last("photo_state")["current"], 1)

    async def test_question_reply_and_guess_confirmation(self):
        await self.join()
        await self.hub.handle(self.a, {"type": "photo_text", "text": "هل هو حيوان؟"})
        self.assertTrue(self.b.last("photo_state")["pending_question"])
        await self.hub.handle(self.b, {"type": "photo_reply", "answer": True})
        self.assertFalse(self.a.last("photo_state")["pending_question"])
        await self.hub.handle(self.a, {"type": "photo_guess", "guess": "test"})
        self.assertTrue(self.b.last("photo_state")["awaiting_confirmation"])
        await self.hub.handle(self.b, {"type": "photo_confirm", "correct": True})
        self.assertEqual(self.a.last("photo_state")["scores"], [1, 0])

    async def test_voice_turn(self):
        await self.join()
        await self.hub.handle(self.a, {"type": "photo_voice_start"})
        self.assertEqual(self.b.last("photo_state")["question_mode"], "voice")
        pcm = base64.b64encode(bytes(1920)).decode("ascii")
        await self.hub.handle(self.a, {"type": "photo_voice", "pcm": pcm})
        self.assertEqual(self.b.last("photo_voice")["pcm"], pcm)
        await self.hub.handle(self.b, {"type": "photo_reply", "answer": True})
        self.assertEqual(self.a.last("photo_state")["current"], 1)

    async def test_disconnect_resume_rotates_token(self):
        await self.join()
        code, player = self.hub.sockets.pop(self.a)
        record = self.hub.rooms[code]
        record["peers"].pop(player)
        record["room"].disconnect(player)
        resumed = FakeSocket()
        await self.hub.handle(resumed, {"type": "photo_resume", "code": code, "token": self.token_a})
        new_token = resumed.last("photo_resumed")["token"]
        self.assertNotEqual(new_token, self.token_a)
        with self.assertRaises(MatchError):
            await self.hub.handle(FakeSocket(), {"type": "photo_resume", "code": code, "token": self.token_a})
        self.assertEqual(self.b.last("photo_state")["closed"], False)

    async def test_leave_invalidates_room(self):
        await self.join()
        await self.hub.handle(self.a, {"type": "photo_leave"})
        self.assertNotIn(self.code, self.hub.rooms)
        self.assertNotIn(self.a, self.hub.sockets)
        self.assertNotIn(self.b, self.hub.sockets)
        self.assertTrue(self.b.last("photo_state")["closed"])

    async def test_cannot_join_twice(self):
        await self.join()
        with self.assertRaises(MatchError):
            await self.hub.handle(self.outsider, {"type": "photo_join", "code": self.code})


if __name__ == "__main__":
    unittest.main()
