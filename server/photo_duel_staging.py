"""Opt-in Photo Duel WebSocket staging endpoint. NEVER imported by production server.
Run separately: python -m server.photo_duel_staging (from repository root).
Requires websockets >= 12; binds loopback by default.
"""
import asyncio
import json
import os
import secrets
import sys
import time
from pathlib import Path

from websockets.asyncio.server import serve

sys.path.insert(0, str(Path(__file__).resolve().parent))
from photo_room_service import PhotoRoom
from photo_match_protocol import MatchError

MAX_BYTES = 4096
MAX_ROOMS = 100
ROOM_IDLE_SECONDS = 1200
PHOTO_ACTIONS = frozenset({
    "photo_text", "photo_tap", "photo_reply", "photo_guess", "photo_confirm", "photo_pass"
})


class StagingHub:
    def __init__(self):
        self.rooms = {}
        self.sockets = {}
        self.lock = asyncio.Lock()

    async def send(self, ws, payload):
        await ws.send(json.dumps(payload, ensure_ascii=False))

    async def error(self, ws, reason):
        await self.send(ws, {"type": "photo_error", "message": reason})

    def room_code(self):
        for _ in range(20):
            code = secrets.token_hex(4).upper()
            if code not in self.rooms:
                return code
        raise MatchError("No room code available")

    async def notify(self, code):
        record = self.rooms.get(code)
        if record is None:
            return
        room = record["room"]
        for player, ws in list(record["peers"].items()):
            try:
                await self.send(ws, room.view(player))
            except Exception:
                pass

    async def handle(self, ws, message):
        if not isinstance(message, dict):
            raise MatchError("Expected JSON object")
        action = message.get("type")
        if action == "photo_create":
            if ws in self.sockets:
                raise MatchError("Already in room")
            if len(self.rooms) >= MAX_ROOMS:
                raise MatchError("Room capacity reached")
            settings = {k: message[k] for k in ("target", "timer", "reward") if k in message}
            code = self.room_code()
            first = secrets.token_hex(16)
            second = secrets.token_hex(16)
            room = PhotoRoom((first, second), **settings)
            self.rooms[code] = {"room": room, "peers": {first: ws}, "created": time.monotonic()}
            self.sockets[ws] = (code, first)
            await self.send(ws, {"type": "photo_created", "code": code, "token": room.tokens[first]})
            await self.send(ws, {"type": "photo_waiting"})
            return
        if action == "photo_join":
            if ws in self.sockets:
                raise MatchError("Already in room")
            code = message.get("code")
            record = self.rooms.get(code) if isinstance(code, str) else None
            if record is None or record["room"].closed:
                raise MatchError("Room unavailable")
            room = record["room"]
            second = room.match.players[1]
            if second in record["peers"]:
                raise MatchError("Room full")
            if room.disconnected:
                raise MatchError("Use resume for disconnected players")
            record["peers"][second] = ws
            self.sockets[ws] = (code, second)
            await self.send(ws, {"type": "photo_joined", "code": code, "token": room.tokens[second]})
            await self.notify(code)
            return
        if action == "photo_resume":
            if ws in self.sockets:
                raise MatchError("Already in room")
            code, token = message.get("code"), message.get("token")
            record = self.rooms.get(code) if isinstance(code, str) else None
            if record is None:
                raise MatchError("Room unavailable")
            room = record["room"]
            player = room.authenticate(token)
            if player in record["peers"]:
                raise MatchError("Original socket still connected")
            new_token, state = room.resume(token)
            record["peers"][player] = ws
            self.sockets[ws] = (code, player)
            await self.send(ws, {"type": "photo_resumed", "code": code, "token": new_token})
            await self.notify(code)
            return
        binding = self.sockets.get(ws)
        if binding is None:
            raise MatchError("Not in a room")
        code, player = binding
        record = self.rooms.get(code)
        if record is None:
            raise MatchError("Room expired")
        room = record["room"]
        if action == "photo_leave":
            room.leave(player)
            await self.notify(code)
            self.rooms.pop(code, None)
            for peer in record["peers"].values():
                self.sockets.pop(peer, None)
            return
        if action == "photo_sync":
            await self.send(ws, room.view(player))
            return
        if action not in PHOTO_ACTIONS:
            raise MatchError("Unsupported action")
        # Identity is taken only from socket binding. Ignore any client 'player'/'facts'.
        events = room.handle(player, message)
        for event in events if isinstance(events, list) else [events]:
            for peer in record["peers"].values():
                await self.send(peer, event)
        await self.notify(code)

    async def connected(self, ws):
        try:
            async for raw in ws:
                if not isinstance(raw, str) or len(raw.encode("utf-8")) > MAX_BYTES:
                    await self.error(ws, "Message too large")
                    continue
                try:
                    data = json.loads(raw)
                    async with self.lock:
                        await self.handle(ws, data)
                except (ValueError, MatchError, TypeError, KeyError) as exc:
                    await self.error(ws, str(exc)[:160])
        finally:
            async with self.lock:
                binding = self.sockets.pop(ws, None)
                if binding:
                    code, player = binding
                    record = self.rooms.get(code)
                    if record:
                        record["peers"].pop(player, None)
                        record["room"].disconnect(player)
                        await self.notify(code)

    async def sweep(self):
        while True:
            await asyncio.sleep(1)
            async with self.lock:
                now = time.monotonic()
                for code, record in list(self.rooms.items()):
                    room = record["room"]
                    if now - record["created"] > ROOM_IDLE_SECONDS or any(now - t > 85 for t in room.disconnected.values()):
                        room.closed = True
                        await self.notify(code)
                        self.rooms.pop(code, None)
                        for peer in record["peers"].values():
                            self.sockets.pop(peer, None)
                        continue
                    if len(record["peers"]) == 2 and not room.disconnected:
                        before = room.match.current
                        event = room.match.expire_turn()
                        if event:
                            room._facts()
                            for peer in record["peers"].values():
                                try:
                                    await self.send(peer, event)
                                except Exception:
                                    pass
                            await self.notify(code)


async def main():
    host = os.getenv("GAMINGHUB_PHOTO_STAGING_HOST", "127.0.0.1")
    if host not in ("127.0.0.1", "localhost", "::1"):
        raise RuntimeError("Staging must bind loopback only")
    port = int(os.getenv("GAMINGHUB_PHOTO_STAGING_PORT", "8769"))
    hub = StagingHub()
    async with serve(hub.connected, host, port, max_size=MAX_BYTES, max_queue=16):
        await hub.sweep()


if __name__ == "__main__":
    asyncio.run(main())
