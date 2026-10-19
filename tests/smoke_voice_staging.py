"""Read-only-to-production staging smoke test: creates a disposable room on staging only.

Run: python tests/smoke_voice_staging.py
Requires: pip install websockets
"""
import asyncio
import base64
import json
import os
from urllib.parse import urlparse

import websockets

URL = os.environ.get("GAMINGHUB_STAGING_WS", "wss://gaminghub-voice-staging.onrender.com")
if urlparse(URL).hostname != "gaminghub-voice-staging.onrender.com":
    raise SystemExit("Refusing to test non-staging host")


async def receive_type(ws, kind, timeout=15):
    async def read():
        while True:
            packet = json.loads(await ws.recv())
            if packet.get("type") == "error":
                raise AssertionError(f"Server error: {packet}")
            if packet.get("type") == kind:
                return packet
    return await asyncio.wait_for(read(), timeout)


async def main():
    async with websockets.connect(URL, open_timeout=65, ping_timeout=20) as a:
        await a.send(json.dumps({"type": "ping", "id": 419}))
        assert (await receive_type(a, "pong"))["id"] == 419
        await a.send(json.dumps({"type": "create"}))
        room = await receive_type(a, "room")
        code = room["code"]
        assert len(code) == 6
        async with websockets.connect(URL, open_timeout=20) as b:
            await b.send(json.dumps({"type": "join", "code": code}))
            assert (await receive_type(b, "room"))["status"] == "joined"
            start_a, start_b = await asyncio.gather(receive_type(a, "started"), receive_type(b, "started"))
            assert start_a["room"] == start_b["room"] == code
            await a.send(json.dumps({"type": "voice_state", "enabled": True, "request_id": 1}))
            ack_a = await receive_type(a, "voice_state_ack")
            await receive_type(b, "voice_state")
            assert ack_a["protocol"] == 2 and not ack_a["peer_enabled"]
            await b.send(json.dumps({"type": "voice_state", "enabled": True, "request_id": 2}))
            ack_b = await receive_type(b, "voice_state_ack")
            peer_a = await receive_type(a, "voice_state")
            assert ack_b["protocol"] == peer_a["protocol"] == 2
            assert ack_b["local_enabled"] and ack_b["peer_enabled"]
            assert peer_a["local_enabled"] and peer_a["peer_enabled"]
            # Exercise real v2 PCM relay with a synthetic 20 ms frame; no microphone claim.
            frame = base64.b64encode(bytes(640)).decode("ascii")
            epoch = ack_b["epoch"]
            assert epoch == peer_a["epoch"]
            await a.send(json.dumps({"type": "voice_audio", "pcm": frame, "epoch": epoch, "seq": 1}))
            audio = await receive_type(b, "voice_audio")
            assert audio["pcm"] == frame and audio["epoch"] == epoch
            assert audio["seq"] == 1 and audio["player"] == start_a["player_index"]
            # A duplicate sequence must not be relayed.
            await a.send(json.dumps({"type": "voice_audio", "pcm": frame, "epoch": epoch, "seq": 1}))
            try:
                unexpected = await asyncio.wait_for(b.recv(), timeout=0.35)
                raise AssertionError(f"Duplicate audio was relayed: {unexpected}")
            except asyncio.TimeoutError:
                pass
            await a.send(json.dumps({"type": "ping", "id": 420}))
            assert (await receive_type(a, "pong"))["id"] == 420
            print("STAGING_SMOKE_PASS: ping, room, join, consent, PCM relay and duplicate rejection protocol=2")


if __name__ == "__main__":
    asyncio.run(main())
