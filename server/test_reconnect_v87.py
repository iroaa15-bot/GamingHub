"""Real local WebSocket tests for capability-based reconnect and authoritative snapshots."""
import asyncio
import json
import unittest
from websockets.asyncio.server import serve
from websockets.asyncio.client import connect
import server

async def tx(ws, kind, **kwargs):
    await ws.send(json.dumps({'type': kind, **kwargs}))

async def rx(ws):
    return json.loads(await asyncio.wait_for(ws.recv(), timeout=3))

class ReconnectV87(unittest.IsolatedAsyncioTestCase):
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

    async def disconnect_a(self):
        await self.a.close()
        self.assertEqual((await rx(self.b))['type'], 'paused')
        self.a = await connect(self.url)

    async def test_resume_restores_same_room_turn_and_no_secret(self):
        await tx(self.a, 'ask', question=0)
        await rx(self.a); await rx(self.b); await rx(self.a); await rx(self.b)
        await self.disconnect_a()
        await tx(self.a, 'resume', code=self.code, token=self.start_a['resume_token'])
        snap = await rx(self.a)
        self.assertEqual(snap['type'], 'resumed')
        self.assertEqual(snap['room'], self.code)
        self.assertEqual(snap['player_index'], 0)
        self.assertFalse(snap['your_turn'])
        self.assertEqual(snap['moves'], 1)
        self.assertEqual(len(snap['history']), 1)
        self.assertEqual(snap['history'][0]['question_index'], 0)
        self.assertNotEqual(snap['resume_token'], self.start_a['resume_token'])
        self.assertEqual(snap['opponent_card']['name'], server.rooms[self.code].cards[1]['name'])
        self.assertNotIn('own_card', snap)
        self.assertNotIn('cards', snap)
        self.assertEqual((await rx(self.b))['type'], 'peer_resumed')
        self.assertEqual(server.rooms[self.code].moves, 1)

    async def test_wrong_token_and_room_code_cannot_steal_session(self):
        await self.disconnect_a()
        await tx(self.a, 'resume', code=self.code, token='0'*64)
        self.assertEqual((await rx(self.a))['message'], 'Invalid resume credentials')
        await tx(self.a, 'resume', code='XXXXXX', token=self.start_a['resume_token'])
        self.assertEqual((await rx(self.a))['message'], 'Match unavailable')
        self.assertIsNone(server.rooms[self.code].players[0])

    async def test_replay_old_token_fails_after_rotation(self):
        await self.disconnect_a()
        await tx(self.a, 'resume', code=self.code, token=self.start_a['resume_token'])
        snap = await rx(self.a); await rx(self.b)
        await self.a.close()
        await rx(self.b)
        self.a = await connect(self.url)
        await tx(self.a, 'resume', code=self.code, token=self.start_a['resume_token'])
        self.assertEqual((await rx(self.a))['type'], 'error')
        await tx(self.a, 'resume', code=self.code, token=snap['resume_token'])
        self.assertEqual((await rx(self.a))['type'], 'resumed')
        await rx(self.b)

    async def test_pause_blocks_moves_and_resume_allows_them(self):
        await self.b.close()
        self.assertEqual((await rx(self.a))['type'], 'paused')
        await tx(self.a, 'ask', question=0)
        self.assertIn('paused', (await rx(self.a))['message'])
        self.assertEqual(server.rooms[self.code].moves, 0)
        self.b = await connect(self.url)
        await tx(self.b, 'resume', code=self.code, token=self.start_b['resume_token'])
        self.assertEqual((await rx(self.b))['type'], 'resumed')
        await rx(self.a)
        await tx(self.a, 'ask', question=0)
        self.assertEqual((await rx(self.a))['type'], 'question')
        await rx(self.b); await rx(self.a); await rx(self.b)
        self.assertEqual(server.rooms[self.code].moves, 1)

    async def test_expiry_cleans_room_and_notifies_peer(self):
        await self.disconnect_a()
        room = server.rooms[self.code]
        await server.expire_stale_rooms(room.detached_at[0] + server.RECONNECT_GRACE + 0.01)
        self.assertEqual((await rx(self.b))['type'], 'disconnected')
        self.assertNotIn(self.code, server.rooms)
        await tx(self.a, 'resume', code=self.code, token=self.start_a['resume_token'])
        self.assertEqual((await rx(self.a))['type'], 'error')

    async def test_two_disconnected_players_can_both_resume(self):
        await self.a.close()
        await rx(self.b)
        await self.b.close()
        self.a = await connect(self.url)
        self.b = await connect(self.url)
        await tx(self.a, 'resume', code=self.code, token=self.start_a['resume_token'])
        a = await rx(self.a)
        self.assertTrue(a['paused'])
        await tx(self.b, 'resume', code=self.code, token=self.start_b['resume_token'])
        b = await rx(self.b)
        self.assertFalse(b['paused'])
        self.assertEqual((await rx(self.a))['type'], 'peer_resumed')
        self.assertEqual((await rx(self.b))['type'], 'peer_resumed')
        self.assertEqual(server.rooms[self.code].moves, 0)

    async def test_finished_result_recoverable_after_dropped_packet(self):
        # Simulate the network dropping after the server has accepted a winning guess.
        answer = server.rooms[self.code].cards[0]['aliases'][0]
        await tx(self.a, 'guess', guess=answer)
        self.assertEqual((await rx(self.a))['type'], 'guess')
        await rx(self.b)
        self.assertEqual((await rx(self.a))['type'], 'finished')
        await rx(self.b)
        await self.disconnect_a()
        await tx(self.a, 'resume', code=self.code, token=self.start_a['resume_token'])
        snap = await rx(self.a)
        self.assertTrue(snap['finished'])
        self.assertEqual(snap['history'][-1]['type'], 'finished')
        self.assertEqual(snap['history'][-1]['winner'], 0)
        self.assertEqual((await rx(self.b))['type'], 'peer_resumed')

    async def test_duplicate_question_after_resume_does_not_count_twice(self):
        await tx(self.a, 'ask', question=0)
        await rx(self.a); await rx(self.b); await rx(self.a); await rx(self.b)
        await self.disconnect_a()
        await tx(self.a, 'resume', code=self.code, token=self.start_a['resume_token'])
        await rx(self.a); await rx(self.b); await rx(self.a)
        # It is player B's turn; an accidental replay cannot advance the game.
        await tx(self.a, 'ask', question=0)
        self.assertEqual((await rx(self.a))['message'], 'Wait for your turn')
        self.assertEqual(server.rooms[self.code].moves, 1)

    async def test_no_resume_while_original_connected(self):
        intruder = await connect(self.url)
        try:
            await tx(intruder, 'resume', code=self.code, token=self.start_a['resume_token'])
            self.assertEqual((await rx(intruder))['message'], 'Original player still connected')
        finally:
            await intruder.close()

if __name__ == '__main__': unittest.main()
