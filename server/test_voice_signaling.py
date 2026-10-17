"""Isolated consent/signaling regression checks for Gaming Hub room server."""
import asyncio
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

    async def test_outsider_cannot_signal(self):
        await process(self.outsider, {"type": "voice_state", "enabled": True})
        self.assertEqual(self.outsider.messages[-1]["type"], "error")

    async def test_invalid_ice_is_rejected(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        await process(self.a, {"type": "voice_ice", "payload": {"candidate": "x" * 4097}})
        self.assertEqual(self.a.messages[-1]["type"], "error")


if __name__ == "__main__":
    unittest.main()
