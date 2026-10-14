"""Integration tests against real local WebSocket connections (not mocks)."""
import asyncio
import json
import time
import unittest
from websockets.asyncio.server import serve
from websockets.asyncio.client import connect
import server

async def tx(ws, kind, **args):
    await ws.send(json.dumps({'type':kind, **args}))

async def rx(ws):
    return json.loads(await asyncio.wait_for(ws.recv(), timeout=3))

class NetworkSyncV88(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        server.rooms.clear(); server.connections.clear(); server.waiting.clear()
        self.listener = await serve(server.handler, '127.0.0.1', 0)
        self.url = f'ws://127.0.0.1:{self.listener.sockets[0].getsockname()[1]}'
        self.a = await connect(self.url)
        self.b = await connect(self.url)
        await tx(self.a, 'create')
        self.code = (await rx(self.a))['code']
        await tx(self.b, 'join', code=self.code)
        await rx(self.b)
        self.start_a = await rx(self.a)
        self.start_b = await rx(self.b)

    async def asyncTearDown(self):
        await self.a.close(); await self.b.close()
        self.listener.close(); await self.listener.wait_closed()
        server.rooms.clear(); server.connections.clear(); server.waiting.clear()

    async def test_heartbeat_returns_nonce_no_secrets(self):
        await tx(self.a, 'ping', id=123456)
        self.assertEqual(await rx(self.a), {'type':'pong','id':123456})
        await tx(self.b, 'ping', id=987)
        self.assertEqual(await rx(self.b), {'type':'pong','id':987})

    async def test_invalid_ping_does_not_disclose_data(self):
        await tx(self.a, 'ping', id='bad')
        self.assertEqual((await rx(self.a))['message'], 'Invalid ping')

    async def test_sync_after_lost_ack_is_authoritative_and_does_not_advance(self):
        await tx(self.a, 'ask', question=0)
        # Consume events as if client had received them, then request sync.
        self.assertEqual((await rx(self.a))['type'], 'question')
        await rx(self.b)
        self.assertEqual((await rx(self.a))['type'], 'turn')
        await rx(self.b)
        await tx(self.a, 'sync')
        snapshot = await rx(self.a)
        self.assertEqual(snapshot['type'], 'synced')
        self.assertEqual(snapshot['moves'], 1)
        self.assertEqual(snapshot['player_index'], 0)
        self.assertEqual(snapshot['history'][0]['question_index'], 0)
        self.assertFalse(snapshot['your_turn'])
        self.assertNotIn('resume_token', snapshot)
        self.assertNotIn('own_card', snapshot)
        self.assertNotIn('cards', snapshot)
        self.assertEqual(server.rooms[self.code].moves, 1)

    async def test_sync_cannot_be_used_by_stranger_with_room_code(self):
        intruder = await connect(self.url)
        try:
            await tx(intruder, 'sync', code=self.code, token=self.start_a['resume_token'])
            self.assertEqual((await rx(intruder))['message'], 'No active match')
        finally:
            await intruder.close()

    async def test_sync_paused_match_preserves_turn_and_history(self):
        await self.b.close()
        self.assertEqual((await rx(self.a))['type'], 'paused')
        await tx(self.a, 'sync')
        snapshot = await rx(self.a)
        self.assertTrue(snapshot['paused'])
        self.assertTrue(snapshot['your_turn'])
        self.assertEqual(snapshot['moves'], 0)
        self.assertEqual(snapshot['history'], [])

    async def test_sync_finished_match_reveals_only_finished_result(self):
        answer = server.rooms[self.code].cards[0]['aliases'][0]
        await tx(self.a, 'guess', guess=answer)
        await rx(self.a); await rx(self.b); await rx(self.a); await rx(self.b)
        await tx(self.a, 'sync')
        snapshot = await rx(self.a)
        self.assertTrue(snapshot['finished'])
        self.assertEqual(snapshot['history'][-1]['type'], 'finished')
        self.assertEqual(snapshot['history'][-1]['winner'], 0)
        self.assertEqual(snapshot['moves'], 0)  # Existing server counts nonwinning moves.

    async def test_ping_sync_do_not_keep_abandoned_room_alive(self):
        room = server.rooms[self.code]
        room.last_activity -= 5
        previous = room.last_activity
        await tx(self.a, 'ping', id=1); await rx(self.a)
        await tx(self.a, 'sync'); await rx(self.a)
        self.assertEqual(room.last_activity, previous)

    async def test_snapshot_has_no_token_except_authenticated_resume(self):
        room = server.rooms[self.code]
        self.assertNotIn('resume_token', server.snapshot(room, 0))
        self.assertIn('resume_token', server.snapshot(room, 0, 'resumed', True))
        self.assertNotIn('cards', server.snapshot(room, 1))

if __name__ == '__main__': unittest.main()
