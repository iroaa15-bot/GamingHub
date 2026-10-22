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

    async def wait_for_voice(self, socket, kind):
        async with asyncio.timeout(0.5):
            while True:
                matches = [m for m in socket.messages if m.get("type") == kind]
                if matches:
                    return matches[-1]
                await asyncio.sleep(0.005)

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
        delivered = await self.wait_for_voice(self.a, "voice_offer")
        self.assertEqual(delivered["payload"]["sdp"], "v=0")

    async def test_large_sdp_relay_and_reject_oversize(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        for kind in ("voice_offer", "voice_answer"):
            sdp = "v=0\\r\\n" + "a" * 11990
            receiver = self.b if kind == "voice_offer" else self.a
            sender = self.a if kind == "voice_offer" else self.b
            await process(sender, {"type": kind, "payload": {"sdp": sdp}})
            delivered = await self.wait_for_voice(receiver, kind)
            self.assertEqual(delivered["payload"]["sdp"], sdp)
            count = len(receiver.messages)
            await process(sender, {"type": kind, "payload": {"sdp": "x" * 16001}})
            self.assertEqual(sender.messages[-1]["type"], "error")
            self.assertEqual(len(receiver.messages), count)

    async def test_large_non_sdp_payload_is_rejected(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        count = len(self.b.messages)
        await process(self.a, {"type": "voice_ice", "payload": {"candidate": "x" * 6100}})
        self.assertEqual(self.a.messages[-1]["type"], "error")
        self.assertEqual(len(self.b.messages), count)

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
        await self.wait_for_voice(self.b, "voice_offer")
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

    async def test_audio_burst_frames_are_preserved_and_flood_limited(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        packet = base64.b64encode(bytes(640)).decode("ascii")
        before = len(self.b.messages)
        # A mobile scheduling stall may deliver multiple legitimate frames together.
        await process(self.a, {"type": "voice_audio", "pcm": packet})
        await process(self.a, {"type": "voice_audio", "pcm": packet})
        self.assertEqual(len(self.b.messages), before + 2)
        # Sustained floods are still limited to 80 frames per rolling second.
        for _ in range(100):
            await process(self.a, {"type": "voice_audio", "pcm": packet})
        self.assertEqual(len(self.b.messages), before + 80)

    async def test_invalid_ice_is_rejected(self):
        await process(self.a, {"type": "voice_state", "enabled": True})
        await process(self.b, {"type": "voice_state", "enabled": True})
        await process(self.a, {"type": "voice_ice", "payload": {"candidate": "x" * 4097}})
        self.assertEqual(self.a.messages[-1]["type"], "error")


if __name__ == "__main__":
    unittest.main()
