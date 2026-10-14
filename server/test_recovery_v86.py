"""Actual local WebSocket protocol integration tests for cancellation/re-entry."""
import asyncio, json, unittest
from websockets.asyncio.server import serve
from websockets.asyncio.client import connect
import server

async def tx(ws, kind, **kwargs):
 await ws.send(json.dumps({'type':kind, **kwargs}))
async def rx(ws):
 return json.loads(await asyncio.wait_for(ws.recv(), timeout=3))

class RecoveryProtocol(unittest.IsolatedAsyncioTestCase):
 async def asyncSetUp(self):
  server.rooms.clear();server.connections.clear();server.waiting.clear()
  self.listener=await serve(server.handler,'127.0.0.1',0)
  self.url=f'ws://127.0.0.1:{self.listener.sockets[0].getsockname()[1]}'
  self.a=await connect(self.url)
  self.b=await connect(self.url)
 async def asyncTearDown(self):
  await self.a.close();await self.b.close()
  self.listener.close();await self.listener.wait_closed()
  server.rooms.clear();server.connections.clear();server.waiting.clear()
 async def test_leave_after_queue_and_rejoin(self):
  await tx(self.a,'matchmake');self.assertEqual((await rx(self.a))['status'],'waiting')
  await tx(self.a,'leave');self.assertEqual((await rx(self.a))['type'],'left')
  self.assertFalse(server.waiting)
  await tx(self.a,'create');code=(await rx(self.a))['code']
  await tx(self.b,'join',code=code)
  self.assertEqual((await rx(self.b))['type'],'room')
  self.assertEqual((await rx(self.a))['type'],'started')
  self.assertEqual((await rx(self.b))['type'],'started')
 async def test_leave_immediately_after_create_then_create_again(self):
  await tx(self.a,'create');await tx(self.a,'leave')
  self.assertEqual((await rx(self.a))['type'],'room')
  self.assertEqual((await rx(self.a))['type'],'left')
  self.assertFalse(server.rooms)
  await tx(self.a,'create')
  self.assertEqual((await rx(self.a))['type'],'room')
 async def test_disconnect_active_game_then_fresh_match(self):
  await tx(self.a,'create');code=(await rx(self.a))['code']
  await tx(self.b,'join',code=code)
  await rx(self.b);await rx(self.a);await rx(self.b)
  await self.a.close()
  self.assertEqual((await rx(self.b))['type'],'paused')
  self.assertIn(code,server.rooms)
  self.a=await connect(self.url)
  await tx(self.a,'create')
  self.assertEqual((await rx(self.a))['type'],'room')
 async def test_turn_progress_after_failed_guess(self):
  await tx(self.a,'create');code=(await rx(self.a))['code']
  await tx(self.b,'join',code=code)
  await rx(self.b);await rx(self.a);await rx(self.b)
  await tx(self.a,'guess',guess='__not_a_card__')
  self.assertFalse((await rx(self.a))['correct'])
  self.assertFalse((await rx(self.b))['correct'])
  self.assertEqual((await rx(self.a))['player'],1)
  self.assertEqual((await rx(self.b))['player'],1)
  self.assertEqual(server.rooms[code].moves,1)
if __name__=='__main__':unittest.main()
