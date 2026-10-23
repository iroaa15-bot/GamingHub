"""Production-integration gate: real WebSocket gameplay + v2 voice state coexistence.

Run from server/: python -m unittest test_voice_protocol_integration.py -v
No production services or external sockets are contacted.
"""
import asyncio
import json
import unittest

from websockets.asyncio.client import connect
from websockets.asyncio.server import serve
import server


async def send(ws, kind, **payload):
    await ws.send(json.dumps({"type": kind, **payload}))


async def recv(ws):
    return json.loads(await asyncio.wait_for(ws.recv(), timeout=3))


class VoiceProtocolIntegrationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        server.rooms.clear()
        server.connections.clear()
        server.waiting.clear()
        self.listener = await serve(server.handler, "127.0.0.1", 0)
        self.port = self.listener.sockets[0].getsockname()[1]
        self.a = await connect(f"ws://127.0.0.1:{self.port}")
        self.b = await connect(f"ws://127.0.0.1:{self.port}")

    async def asyncTearDown(self):
        await self.a.close()
        await self.b.close()
        self.listener.close()
        await self.listener.wait_closed()
        server.rooms.clear()
        server.connections.clear()
        server.waiting.clear()

    async def test_private_room_voice_v2_and_normal_turn(self):
        await send(self.a, "create")
        code = (await recv(self.a))["code"]
        await send(self.b, "join", code=code)
        self.assertEqual((await recv(self.b))["status"], "joined")
        self.assertEqual((await recv(self.a))["type"], "started")
        self.assertEqual((await recv(self.b))["type"], "started")

        # Each player opts in independently; the server returns protocol and epoch.
        await send(self.a, "voice_state", enabled=True, request_id=1)
        peer_state = await recv(self.b)
        first_ack = await recv(self.a)
        self.assertEqual(peer_state["type"], "voice_state")
        self.assertEqual(first_ack["type"], "voice_state_ack")
        self.assertEqual(first_ack["protocol"], 2)
        self.assertEqual(first_ack["request_id"], 1)
        self.assertTrue(first_ack["local_enabled"])
        self.assertFalse(first_ack["peer_enabled"])

        await send(self.b, "voice_state", enabled=True, request_id=2)
        peer_state = await recv(self.a)
        second_ack = await recv(self.b)
        self.assertEqual(peer_state["type"], "voice_state")
        self.assertEqual(second_ack["type"], "voice_state_ack")
        self.assertEqual(second_ack["protocol"], 2)
        self.assertEqual(second_ack["request_id"], 2)
        self.assertEqual(second_ack["epoch"], peer_state["epoch"])
        self.assertTrue(second_ack["local_enabled"])
        self.assertTrue(second_ack["peer_enabled"])

        # Voice activation must not break ordinary question and turn messages.
        await send(self.a, "ask", question=0)
        for ws in (self.a, self.b):
            self.assertEqual((await recv(ws))["type"], "question")
        for ws in (self.a, self.b):
            self.assertEqual((await recv(ws))["type"], "turn")
        self.assertEqual(server.rooms[code].moves, 1)

        # Disabling consent invalidates the prior voice session without
        # destroying the room or the gameplay turn.
        previous_epoch = second_ack["epoch"]
        await send(self.b, "voice_state", enabled=False, request_id=3)
        off_state = await recv(self.a)
        off_ack = await recv(self.b)
        self.assertEqual(off_state["type"], "voice_state")
        self.assertEqual(off_ack["type"], "voice_state_ack")
        self.assertGreater(off_ack["epoch"], previous_epoch)
        self.assertFalse(off_ack["local_enabled"])
        self.assertIn(code, server.rooms)
        self.assertEqual(server.rooms[code].moves, 1)


if __name__ == "__main__":
    unittest.main()
