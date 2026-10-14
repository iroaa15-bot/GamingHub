"""Integration tests for the matchmaking and private-room protocol."""
import asyncio, json, unittest
from websockets.asyncio.server import serve
from websockets.asyncio.client import connect
import server

async def send(ws, typ, **kwargs):
    await ws.send(json.dumps({'type':typ, **kwargs}))

async def recv(ws):
    return json.loads(await asyncio.wait_for(ws.recv(), timeout=3))

class MultiplayerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        server.rooms.clear(); server.connections.clear(); server.waiting.clear()
        self.listener = await serve(server.handler, '127.0.0.1', 0)
        self.port = self.listener.sockets[0].getsockname()[1]
        self.a = await connect(f'ws://127.0.0.1:{self.port}')
        self.b = await connect(f'ws://127.0.0.1:{self.port}')

    async def asyncTearDown(self):
        await self.a.close(); await self.b.close()
        self.listener.close(); await self.listener.wait_closed()

    async def test_matchmaking_and_hidden_cards(self):
        await send(self.a, 'matchmake')
        self.assertEqual((await recv(self.a))['status'], 'waiting')
        await send(self.b, 'matchmake')
        self.assertEqual((await recv(self.a))['type'], 'room')
        self.assertEqual((await recv(self.b))['type'], 'room')
        x, y = await recv(self.a), await recv(self.b)
        self.assertEqual(x['type'], 'started')
        self.assertEqual(y['type'], 'started')
        self.assertNotEqual(x['opponent_card'], y['opponent_card'])
        room = server.rooms[x['room']]
        self.assertEqual(x['opponent_card']['name'], room.cards[1]['name'])
        self.assertNotIn(room.cards[0]['name'], json.dumps(x) if room.cards[0]['name'] != room.cards[1]['name'] else '')
        await send(self.b, 'ask', question=0)
        self.assertEqual((await recv(self.b))['type'], 'error')
        await send(self.a, 'ask', question=0)
        self.assertEqual((await recv(self.a))['type'], 'question')
        self.assertEqual((await recv(self.b))['type'], 'question')
        self.assertEqual((await recv(self.a))['type'], 'turn')
        self.assertEqual((await recv(self.b))['type'], 'turn')

    async def test_private_room(self):
        await send(self.a, 'create')
        code = (await recv(self.a))['code']
        await send(self.b, 'join', code=code)
        self.assertEqual((await recv(self.b))['status'], 'joined')
        self.assertEqual((await recv(self.a))['type'], 'started')
        self.assertEqual((await recv(self.b))['type'], 'started')

    async def test_repeated_question_is_rejected(self):
        await send(self.a, 'create')
        code = (await recv(self.a))['code']
        await send(self.b, 'join', code=code)
        await recv(self.b); await recv(self.a); await recv(self.b)
        await send(self.a, 'ask', question=0)
        await recv(self.a); await recv(self.b); await recv(self.a); await recv(self.b)
        await send(self.b, 'ask', question=1)
        await recv(self.a); await recv(self.b); await recv(self.a); await recv(self.b)
        await send(self.a, 'ask', question=0)
        result = await recv(self.a)
        self.assertEqual(result['type'], 'error')
        self.assertEqual(result['message'], 'Question already asked')

    async def test_leave_cleans_room(self):
        await send(self.a, 'create')
        code = (await recv(self.a))['code']
        await send(self.b, 'join', code=code)
        await recv(self.b); await recv(self.a); await recv(self.b)
        await send(self.a, 'leave')
        self.assertEqual((await recv(self.b))['type'], 'disconnected')
        self.assertEqual((await recv(self.a))['type'], 'left')
        self.assertNotIn(code, server.rooms)
        self.assertNotIn(self.a, server.connections)
        self.assertNotIn(self.b, server.connections)

    async def test_queued_player_cannot_create_room(self):
        await send(self.a, 'matchmake'); await recv(self.a)
        await send(self.a, 'create')
        self.assertEqual((await recv(self.a))['type'], 'error')
        self.assertEqual(len(server.rooms), 0)

    async def test_cancel_queue(self):
        await send(self.a, 'matchmake'); await recv(self.a)
        await send(self.a, 'cancel_queue')
        self.assertEqual((await recv(self.a))['status'], 'cancelled')
        self.assertEqual(len(server.waiting), 0)

    async def test_guess_type_and_length_validation(self):
        await send(self.a, 'create')
        code = (await recv(self.a))['code']
        await send(self.b, 'join', code=code)
        await recv(self.b); await recv(self.a); await recv(self.b)
        await send(self.a, 'guess', guess=42)
        self.assertEqual((await recv(self.a))['message'], 'Invalid guess')
        await send(self.a, 'guess', guess='X'*81)
        self.assertEqual((await recv(self.a))['message'], 'Guess too long')
        self.assertEqual(server.rooms[code].moves, 0)

    async def test_room_capacity_and_cleanup(self):
        old = server.MAX_ROOMS
        server.MAX_ROOMS = 1
        try:
            await send(self.a, 'create')
            code = (await recv(self.a))['code']
            await send(self.b, 'create')
            self.assertEqual((await recv(self.b))['message'], 'Server is at capacity')
            self.assertEqual(len(server.rooms), 1)
            await server.expire_stale_rooms(server.rooms[code].last_activity + server.WAITING_TTL + 1)
            self.assertEqual((await recv(self.a))['message'], 'Room timed out')
            self.assertFalse(server.rooms)
            self.assertFalse(server.connections)
        finally:
            server.MAX_ROOMS = old

    async def test_expire_active_match_notifies_both(self):
        await send(self.a, 'create')
        code = (await recv(self.a))['code']
        await send(self.b, 'join', code=code)
        await recv(self.b); await recv(self.a); await recv(self.b)
        await server.expire_stale_rooms(server.rooms[code].last_activity + server.MATCH_TTL + 1)
        self.assertEqual((await recv(self.a))['type'], 'disconnected')
        self.assertEqual((await recv(self.b))['type'], 'disconnected')
        self.assertNotIn(code, server.rooms)

    async def test_invalid_action_does_not_advance_turn(self):
        await send(self.a, 'create')
        code = (await recv(self.a))['code']
        await send(self.b, 'join', code=code)
        await recv(self.b); await recv(self.a); await recv(self.b)
        await send(self.a, 'unexpected')
        self.assertEqual((await recv(self.a))['message'], 'Unknown action')
        self.assertEqual(server.rooms[code].turn, 0)

if __name__ == '__main__':
    unittest.main()
