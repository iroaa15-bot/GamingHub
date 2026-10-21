import asyncio
import json
import unittest
from websockets.asyncio.client import connect
from websockets.asyncio.server import serve
import server as app

class WebRtcIsolationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncTearDown(self):
        for room in list(app.rooms.values()): app.reset_voice_media(room)
        app.rooms.clear();app.connections.clear();app.waiting.clear()
    async def test_ice_burst_preserves_gameplay_connection(self):
        async with serve(app.handler,'127.0.0.1',0,compression=None) as listener:
            url=f'ws://127.0.0.1:{listener.sockets[0].getsockname()[1]}'
            async with connect(url) as a, connect(url) as b:
                async def receive(ws,kind):
                    while True:
                        packet=json.loads(await asyncio.wait_for(ws.recv(),3))
                        if packet['type']==kind:return packet
                await a.send(json.dumps({'type':'create'}));code=(await receive(a,'room'))['code']
                await b.send(json.dumps({'type':'join','code':code}));await receive(b,'room')
                await receive(a,'started');await receive(b,'started')
                await a.send(json.dumps({'type':'voice_state','enabled':True}));await receive(a,'voice_state_ack')
                await b.send(json.dumps({'type':'voice_state','enabled':True}));await receive(b,'voice_state_ack')
                for n in range(501):await a.send(json.dumps({'type':'voice_ice','payload':{'candidate':f'candidate:{n}'}}))
                await a.send(json.dumps({'type':'ping','id':442}))
                self.assertEqual((await receive(a,'pong'))['id'],442)
    async def test_slow_peer_never_blocks_gameplay_receive(self):
        class Socket:
            def __init__(self,slow=False):self.slow=slow;self.messages=[]
            async def send(self,raw):
                if self.slow:await asyncio.sleep(5)
                self.messages.append(json.loads(raw))
        a,b=Socket(),Socket(True)
        room=app.Room('ISOLAT',[a,b]);room.cards=[{'name':'A'},{'name':'B'}];room.voice_enabled=[True,True]
        app.rooms[room.code]=room;app.connections[a]=app.connections[b]=room.code
        await asyncio.wait_for(app.process(a,{'type':'voice_offer','payload':{'sdp':'v=0'}}),.1)
        await asyncio.wait_for(app.process(a,{'type':'ping','id':443}),.1)
        self.assertEqual(a.messages[-1]['type'],'pong')
