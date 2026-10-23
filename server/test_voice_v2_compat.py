import asyncio
import base64
import unittest
from server import Room, rooms, connections, process

class Socket:
    def __init__(self):
        self.messages = []
    async def send(self, raw):
        import json
        self.messages.append(json.loads(raw))

class Compatibility(unittest.IsolatedAsyncioTestCase):
    async def test_legacy_and_v2(self):
        a, b = Socket(), Socket()
        room = Room("COMPAT1", [a, b])
        room.cards = [{"name": "A"}, {"name": "B"}]
        rooms["COMPAT1"] = room
        connections[a] = connections[b] = "COMPAT1"
        try:
            await process(a, {"type": "voice_state", "enabled": True})
            await process(b, {"type": "voice_state", "enabled": True})
            pcm = base64.b64encode(bytes(640)).decode("ascii")
            await process(a, {"type": "voice_audio", "pcm": pcm})
            self.assertTrue(any(m == {"type": "voice_audio", "pcm": pcm} for m in b.messages))
            epoch = room.voice_epoch
            await process(a, {"type": "voice_audio", "pcm": pcm, "seq": 1, "epoch": epoch})
            await asyncio.sleep(0.05)
            delivered = [m for m in b.messages if m.get("type") == "voice_audio" and m.get("seq") == 1]
            self.assertEqual(len(delivered), 1)
            await process(a, {"type": "voice_audio", "pcm": pcm, "seq": 1, "epoch": epoch})
            await asyncio.sleep(0.05)
            delivered = [m for m in b.messages if m.get("type") == "voice_audio" and m.get("seq") == 1]
            self.assertEqual(len(delivered), 1)
        finally:
            rooms.pop("COMPAT1", None)
            connections.pop(a, None)
            connections.pop(b, None)

if __name__ == "__main__":
    unittest.main()
