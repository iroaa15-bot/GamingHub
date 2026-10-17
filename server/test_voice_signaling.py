"""Isolated consent/signaling regression checks for Gaming Hub room server."""
import asyncio
import base64
import unittest
from unittest.mock import patch

from server import Room, rooms, connections, process


class FakeSocket:
    def __init__(self):
        self.messages = []

    async def send(self, raw):
        import json
        self.messages.append(json.loads(raw))


class VoiceSignalingTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.a, self.b, self.outsider = FakeSocket(), FakeSocket(), FakeSocket()
        self.room = Room("VOICE1", [self.a, self.b])
        self.room.cards = [{"name": "A"}, {"name": "B"}]
        rooms["VOICE1"] = self.room
        connections[self.a] = connections[self.b] = "VOICE1"

    async def asyncTearDown(self):
        rooms.clear()
        connections.clear()

    async def test_mutual_opt_in_required_and_turn_independent(self):
        offer = {"type": "voice_offer", "payload": {"sdp": "v=0"}}
        await process(self.a, offer)
        self.assertEqual(self.a.messages[-1]["type"], "error")
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.a, offer)
        self.assertEqual(self.a.messages[-1]["type"], "error")
        await process(self.b, {"type": "voice_state", "enabled": True})
        self.room.turn = 0
        await process(self.b, offer)
        self.assertEqual(self.a.messages[-1]["type"], "voice_offer")
        self.assertEqual(self.a.messages[-1]["payload"]["sdp"], "v=0")

    async def test_opt_out_blocks_signaling(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        await process(self.a, {"type": "voice_state", "enabled": False})
        await process(self.b, {"type": "voice_ice", "payload": {"candidate": "candidate:test"}})
        self.assertEqual(self.b.messages[-1]["type"], "error")

    async def test_peer_only_receives_offer(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        before = len(self.outsider.messages)
        await process(self.a, {"type": "voice_offer", "payload": {"sdp": "v=0"}})
        self.assertEqual(self.b.messages[-1]["type"], "voice_offer")
        self.assertEqual(len(self.outsider.messages), before)

    async def test_finished_match_rejects_voice(self):
        self.room.over = True
        await process(self.a, {"type": "voice_state", "enabled": True})
        self.assertEqual(self.a.messages[-1]["type"], "error")

    async def test_invalid_consent_rejected(self):
        await process(self.a, {"type": "voice_state", "enabled": "yes"})
        self.assertEqual(self.a.messages[-1]["type"], "error")
        self.assertEqual(self.room.voice_enabled, [False, False])

    async def test_outsider_cannot_signal(self):
        await process(self.outsider, {"type": "voice_state", "enabled": True})
        self.assertEqual(self.outsider.messages[-1]["type"], "error")

    async def test_reconnect_requires_fresh_consent(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        self.room.resume_tokens = ["a" * 64, "b" * 64]
        self.room.players[0] = None
        self.room.detached_at[0] = __import__("time").monotonic()
        connections.pop(self.a)
        replacement = FakeSocket()
        await process(replacement, {"type": "resume", "code": "VOICE1", "token": "a" * 64})
        self.assertIn("resumed", [message["type"] for message in replacement.messages])
        self.assertEqual(self.room.voice_enabled, [False, False])
        await process(self.b, {"type": "voice_offer", "payload": {"sdp": "v=0"}})
        self.assertEqual(self.b.messages[-1]["type"], "error")

    async def test_resume_notifies_peer_voice_is_off(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        self.room.resume_tokens = ["a" * 64, "b" * 64]
        self.room.players[0] = None
        self.room.detached_at[0] = __import__("time").monotonic()
        connections.pop(self.a)
        replacement = FakeSocket()
        await process(replacement, {"type": "resume", "code": "VOICE1", "token": "a" * 64})
        self.assertTrue(any(message.get("type") == "voice_state" and message.get("enabled") is False for message in self.b.messages))

    async def test_audio_requires_mutual_consent(self):
        packet = base64.b64encode(bytes(640)).decode("ascii")
        await process(self.a, {"type": "voice_audio", "pcm": packet})
        self.assertEqual(self.a.messages[-1]["type"], "error")
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        await process(self.a, {"type": "voice_audio", "pcm": packet})
        self.assertEqual(self.b.messages[-1], {"type": "voice_audio", "pcm": packet})
        await process(self.b, {"type": "voice_state", "enabled": False})
        await process(self.a, {"type": "voice_audio", "pcm": packet})
        self.assertEqual(self.a.messages[-1]["type"], "error")

    async def test_audio_rejects_invalid_packet(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        await process(self.a, {"type": "voice_audio", "pcm": "not-base64"})
        self.assertEqual(self.a.messages[-1]["type"], "error")
        await process(self.a, {"type": "voice_audio", "pcm": "!" * 856})
        self.assertEqual(self.a.messages[-1]["type"], "error")
        await process(self.a, {"type": "voice_audio", "pcm": base64.b64encode(bytes(638)).decode("ascii")})
        self.assertEqual(self.a.messages[-1]["type"], "error")

    async def test_audio_rate_limit_drops_excess_packets(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        packet = base64.b64encode(bytes(640)).decode("ascii")
        before = len(self.b.messages)
        await process(self.a, {"type": "voice_audio", "pcm": packet})
        await process(self.a, {"type": "voice_audio", "pcm": packet})
        self.assertEqual(len(self.b.messages), before + 1)

    async def test_invalid_ice_is_rejected(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        await process(self.a, {"type": "voice_ice", "payload": {"candidate": "x" * 4097}})
        self.assertEqual(self.a.messages[-1]["type"], "error")


if __name__ == "__main__":
    unittest.main()
