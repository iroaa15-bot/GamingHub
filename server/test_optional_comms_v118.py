"""v11.8 opt-in room communication protocol regression tests.

Tests are intentionally local: never send user text to production.
"""
import asyncio
import json
import unittest

from websockets.asyncio.client import connect
from websockets.asyncio.server import serve
import server


async def tx(ws, kind, **data):
    await ws.send(json.dumps({"type": kind, **data}))


async def rx(ws):
    return json.loads(await asyncio.wait_for(ws.recv(), timeout=3))


class OptionalCommsTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        server.rooms.clear()
        server.connections.clear()
        server.waiting.clear()
        self.listener = await serve(server.handler, "127.0.0.1", 0)
        self.url = f"ws://127.0.0.1:{self.listener.sockets[0].getsockname()[1]}"
        self.a = await connect(self.url)
        self.b = await connect(self.url)
        await tx(self.a, "create")
        self.code = (await rx(self.a))["code"]
        await tx(self.b, "join", code=self.code)
        await rx(self.b)
        self.start_a = await rx(self.a)
        self.start_b = await rx(self.b)

    async def asyncTearDown(self):
        await self.a.close()
        await self.b.close()
        self.listener.close()
        await self.listener.wait_closed()
        server.rooms.clear()
        server.connections.clear()
        server.waiting.clear()

    async def consent(self, ws, mode):
        await tx(ws, "comms", mode=mode)
        a, b = await rx(self.a), await rx(self.b)
        self.assertEqual(a["type"], "comms_state")
        self.assertEqual(b["type"], "comms_state")
        return a

    async def test_disabled_by_default_and_both_must_consent(self):
        await tx(self.a, "chat", text="hello")
        self.assertEqual((await rx(self.a))["type"], "error")
        await self.consent(self.a, "text")
        await tx(self.a, "chat", text="still disabled")
        self.assertEqual((await rx(self.a))["type"], "error")
        await self.consent(self.b, "text")
        await tx(self.a, "chat", text="hello")
        a, b = await rx(self.a), await rx(self.b)
        self.assertEqual(a, b)
        self.assertEqual(a, {"type": "chat", "player": 0, "text": "hello"})
        self.assertEqual(server.rooms[self.code].moves, 0)

    async def test_no_voice_signals_without_mutual_consent(self):
        sig = {"kind": "offer", "sdp": "fake"}
        await tx(self.a, "voice_signal", signal=sig)
        self.assertEqual((await rx(self.a))["type"], "error")
        await self.consent(self.a, "voice")
        await tx(self.a, "voice_signal", signal=sig)
        self.assertEqual((await rx(self.a))["type"], "error")
        await self.consent(self.b, "voice")
        await tx(self.a, "voice_signal", signal=sig)
        self.assertEqual((await rx(self.b))["signal"], sig)
        self.assertEqual(server.rooms[self.code].moves, 0)

    async def test_switching_off_stops_text_and_voice(self):
        await self.consent(self.a, "both")
        await self.consent(self.b, "both")
        await self.consent(self.b, "none")
        await tx(self.a, "chat", text="no")
        self.assertEqual((await rx(self.a))["type"], "error")
        await tx(self.a, "voice_signal", signal={"kind": "ice", "candidate": "x"})
        self.assertEqual((await rx(self.a))["type"], "error")

    async def test_block_prevents_re_enable_in_same_match(self):
        await self.consent(self.a, "both")
        await self.consent(self.b, "both")
        await tx(self.b, "comms_block")
        await rx(self.a)
        await rx(self.b)
        await self.consent(self.a, "both")
        await self.consent(self.b, "both")
        await tx(self.a, "chat", text="blocked")
        self.assertEqual((await rx(self.a))["type"], "error")

    async def test_limits_reject_invalid_text_and_flood(self):
        await self.consent(self.a, "text")
        await self.consent(self.b, "text")
        for value in ("", "x" * 181, "control\u0000code"):
            await tx(self.a, "chat", text=value)
            self.assertEqual((await rx(self.a))["type"], "error")
        for i in range(5):
            await tx(self.a, "chat", text=f"m{i}")
            await rx(self.a)
            await rx(self.b)
        await tx(self.a, "chat", text="too many")
        self.assertEqual((await rx(self.a))["message"], "Chat rate limit")
        self.assertEqual(len(server.rooms[self.code].chat_history), 5)

    async def test_outsider_cannot_post_or_signal(self):
        outsider = await connect(self.url)
        try:
            await tx(outsider, "chat", text="intruder", code=self.code)
            self.assertEqual((await rx(outsider))["type"], "error")
            await tx(outsider, "voice_signal", signal={"kind": "offer", "sdp": "x"}, code=self.code)
            self.assertEqual((await rx(outsider))["type"], "error")
        finally:
            await outsider.close()

    async def test_snapshot_contains_chat_but_not_own_secret(self):
        await self.consent(self.a, "text")
        await self.consent(self.b, "text")
        await tx(self.a, "chat", text="what color?")
        await rx(self.a)
        await rx(self.b)
        await tx(self.a, "sync")
        snapshot = await rx(self.a)
        self.assertEqual(snapshot["chat_history"][0]["text"], "what color?")
        self.assertNotIn("own_card", snapshot)
        self.assertNotIn("cards", snapshot)
        self.assertEqual(snapshot["comms"], ["text", "text"])


if __name__ == "__main__":
    unittest.main()
