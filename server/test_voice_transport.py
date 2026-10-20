"""Real localhost WebSockets, PCM bytes and room recovery; no microphone/device claims."""
import asyncio
import base64
import contextlib
import json
import math
import struct
import time
import unittest
from websockets.asyncio.client import connect
from websockets.asyncio.server import serve
import server as app

PCM = base64.b64encode(struct.pack('<320h', *(int(4000 * math.sin(i * math.tau * 440 / 16000)) for i in range(320)))).decode()

async def receive(ws, kind, timeout=3):
    async with asyncio.timeout(timeout):
        while True:
            message = json.loads(await ws.recv())
            if message['type'] == kind:
                return message

async def post(ws, **message):
    await ws.send(json.dumps(message))

class VoiceTransportTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        app.rooms.clear(); app.connections.clear(); app.waiting.clear()
        self.server = await serve(app.handler, '127.0.0.1', 0, ping_interval=None, compression=None)
        self.url = f'ws://127.0.0.1:{self.server.sockets[0].getsockname()[1]}'
        self.clients = [await connect(self.url), await connect(self.url)]
        self.a, self.b = self.clients
        await post(self.a, type='create')
        room = await receive(self.a, 'room'); self.code = room['code']
        await post(self.b, type='join', code=self.code)
        self.started_a = await receive(self.a, 'started')
        await receive(self.b, 'started')

    async def asyncTearDown(self):
        for ws in self.clients:
            await ws.close()
        self.server.close(); await self.server.wait_closed()
        for room in app.rooms.values():
            app.reset_voice_media(room)
        app.rooms.clear(); app.connections.clear(); app.waiting.clear()
        await asyncio.sleep(0)

    async def enable(self, a=None, b=None):
        a, b = a or self.a, b or self.b
        await post(a, type='voice_state', enabled=True, request_id=1)
        await receive(a, 'voice_state_ack')
        await post(b, type='voice_state', enabled=True, request_id=1)
        ack = await receive(b, 'voice_state_ack')
        self.assertEqual(ack['protocol'], 2); self.assertTrue(ack['peer_enabled'])
        return ack['epoch']

    async def test_bidirectional_fifty_fps_keeps_gameplay_and_socket_alive(self):
        epoch = await self.enable()
        async def send_stream(ws):
            for seq in range(1, 111):
                await post(ws, type='voice_audio', pcm=PCM, seq=seq, epoch=epoch)
                if seq in (25, 75):
                    await post(ws, type='ping', id=seq)
                await asyncio.sleep(.020)
        async def consume(ws, player):
            frames, pongs = [], []
            async with asyncio.timeout(8):
                while len(frames) < 110 or len(pongs) < 2:
                    message = json.loads(await ws.recv())
                    if message['type'] == 'voice_audio':
                        self.assertEqual(message['player'], player)
                        self.assertEqual(message['pcm'], PCM)
                        self.assertEqual(len(base64.b64decode(message['pcm'])), 640)
                        self.assertEqual(message['epoch'], epoch)
                        frames.append(message['seq'])
                    elif message['type'] == 'pong': pongs.append(message['id'])
                    elif message['type'] == 'error': self.fail(str(message))
            self.assertEqual(frames, list(range(1, 111))); self.assertEqual(pongs, [25, 75])
        await asyncio.gather(send_stream(self.a), send_stream(self.b), consume(self.a, 1), consume(self.b, 0))
        self.assertEqual(app.rooms[self.code].moves, 0)

    async def test_disconnect_resume_rotates_token_and_requires_new_consent(self):
        epoch = await self.enable()
        token = self.started_a['resume_token']
        await self.a.close()
        await receive(self.b, 'paused')
        reset = await receive(self.b, 'voice_state')
        self.assertTrue(reset['reset']); self.assertFalse(reset['local_enabled'])
        replacement = await connect(self.url); self.clients.append(replacement)
        await post(replacement, type='resume', code=self.code, token=token)
        restored = await receive(replacement, 'resumed')
        self.assertNotEqual(restored['resume_token'], token)
        await receive(self.b, 'peer_resumed')
        await post(replacement, type='voice_audio', pcm=PCM, seq=1, epoch=epoch)
        error = await receive(replacement, 'error'); self.assertEqual(error['scope'], 'voice')
        new_epoch = await self.enable(replacement, self.b); self.assertGreater(new_epoch, epoch)
        await post(replacement, type='voice_audio', pcm=PCM, seq=999, epoch=epoch)
        await post(replacement, type='voice_audio', pcm=PCM, seq=1, epoch=new_epoch)
        packet = await receive(self.b, 'voice_audio')
        self.assertEqual(packet['seq'], 1); self.assertEqual(packet['epoch'], new_epoch)

    async def test_permission_opt_out_duplicate_epoch_and_gameplay_sync(self):
        epoch = await self.enable()
        for seq in (1, 1, 0, 2):
            await post(self.a, type='voice_audio', pcm=PCM, seq=seq, epoch=epoch)
        self.assertEqual((await receive(self.b, 'voice_audio'))['seq'], 1)
        self.assertEqual((await receive(self.b, 'voice_audio'))['seq'], 2)
        await post(self.b, type='voice_state', enabled=False, request_id=2)
        ack = await receive(self.b, 'voice_state_ack'); self.assertFalse(ack['enabled'])
        await post(self.a, type='voice_audio', pcm=PCM, seq=3, epoch=epoch)
        await post(self.a, type='sync')
        error = await receive(self.a, 'error'); self.assertEqual(error['scope'], 'voice')
        sync = await receive(self.a, 'synced'); self.assertEqual(sync['moves'], 0)

class RelayBufferTests(unittest.IsolatedAsyncioTestCase):
    async def asyncTearDown(self):
        for room in app.rooms.values(): app.reset_voice_media(room)
        app.rooms.clear()
        await asyncio.sleep(0)

    async def test_slow_receiver_is_bounded_and_does_not_block_sender(self):
        class Slow:
            closed = False
            async def send(self, raw): await asyncio.sleep(10)
            async def close(self, **kwargs): self.closed = True
        slow = Slow(); room = app.Room('SLOW', [object(), slow]); room.voice_enabled = [True, True]
        app.rooms['SLOW'] = room
        relay = app.VoiceRelay(room, 0); room.voice_relays[0] = relay
        packet = {'type':'voice_audio', 'pcm':PCM, 'seq':0, 'epoch':0}
        start = time.monotonic()
        for seq in range(500): relay.offer(dict(packet, seq=seq))
        self.assertLess(time.monotonic() - start, .1)
        self.assertEqual(len(relay.pending), 6)
        await relay.task
        self.assertTrue(slow.closed); self.assertFalse(relay.pending)

    async def test_queued_old_epoch_and_expired_audio_are_dropped(self):
        class Target:
            messages = []
            async def send(self, raw): self.messages.append(json.loads(raw))
        target = Target(); room = app.Room('TTL', [object(), target]); room.voice_enabled = [True, True]
        app.rooms['TTL'] = room
        relay = app.VoiceRelay(room, 0)
        packet = {'type':'voice_audio','pcm':PCM,'seq':1,'epoch':0}
        relay.pending.append((time.monotonic() - 1, packet))
        relay.pending.append((time.monotonic(), dict(packet, epoch=99)))
        await relay.run(); self.assertFalse(target.messages)

if __name__ == '__main__': unittest.main()
