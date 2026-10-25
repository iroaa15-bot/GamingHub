"""Party Room isolated staging WebSocket transport. Not used by production."""
import asyncio
import json
import os
import secrets
from websockets.asyncio.server import serve
from .party_room_engine import new_room, PartyError

rooms = {}
clients = {}


async def send(ws, value):
    await ws.send(json.dumps(value, ensure_ascii=False))


async def publish(room):
    for member_id in room.members:
        peer = clients.get((room.code, member_id))
        if peer is not None:
            try:
                await send(peer, {"type": "party.state", "state": room.snapshot()})
            except Exception:
                pass


async def handler(ws):
    identity = None
    try:
        async for raw in ws:
            try:
                message = json.loads(raw)
                if not isinstance(message, dict):
                    raise PartyError("invalid_message")
                action = message.get("type")
                if action == "party.create":
                    if identity is not None:
                        raise PartyError("already_joined")
                    if len(rooms) >= 100:
                        raise PartyError("capacity")
                    player = secrets.token_urlsafe(12)
                    room, token = new_room(player, str(message.get("name", "")))
                    while room.code in rooms:
                        room, token = new_room(player, str(message.get("name", "")))
                    rooms[room.code] = room
                    identity = (room.code, player)
                    clients[identity] = ws
                    await send(ws, {"type": "party.auth", "code": room.code, "player_id": player, "resume_token": token})
                elif action == "party.join":
                    if identity is not None:
                        raise PartyError("already_joined")
                    code = str(message.get("code", "")).upper()
                    room = rooms.get(code)
                    if room is None:
                        raise PartyError("room_not_found")
                    player = secrets.token_urlsafe(12)
                    token = room.join(player, str(message.get("name", "")))
                    identity = (code, player)
                    clients[identity] = ws
                    await send(ws, {"type": "party.auth", "code": code, "player_id": player, "resume_token": token})
                elif action == "party.reconnect":
                    if identity is not None:
                        raise PartyError("already_joined")
                    code = str(message.get("code", "")).upper()
                    player = str(message.get("player_id", ""))
                    room = rooms.get(code)
                    if room is None:
                        raise PartyError("room_not_found")
                    room.reconnect(player, str(message.get("resume_token", "")))
                    identity = (code, player)
                    old = clients.get(identity)
                    if old is not None and old is not ws:
                        await old.close()
                    clients[identity] = ws
                    await send(ws, {"type": "party.auth", "code": code, "player_id": player, "resume_token": room.members[player].token})
                else:
                    if identity is None:
                        raise PartyError("authentication_required")
                    room = rooms[identity[0]]
                    player = identity[1]
                    if action == "party.ready":
                        room.ready(player, message.get("ready") is True)
                    elif action == "party.start":
                        room.start(player)
                    elif action == "party.submit":
                        room.submit(player, message.get("answer"), str(message.get("request_id", "")))
                    elif action == "party.reveal":
                        room.reveal(player)
                    elif action == "party.next":
                        room.next_round(player)
                    elif action != "party.state":
                        raise PartyError("unknown_action")
                if identity is not None:
                    await publish(rooms[identity[0]])
            except (ValueError, TypeError, KeyError) as exc:
                await send(ws, {"type": "party.error", "error": str(exc)[:100]})
    finally:
        if identity is not None and clients.get(identity) is ws:
            clients.pop(identity, None)
            room = rooms.get(identity[0])
            if room is not None:
                room.disconnect(identity[1])
                await publish(room)


async def main():
    host = os.getenv("GAMINGHUB_PARTY_STAGING_HOST", "127.0.0.1")
    port = int(os.getenv("GAMINGHUB_PARTY_STAGING_PORT", "8771"))
    async with serve(handler, host, port, max_size=4096):
        print(f"Party Room staging on {host}:{port}", flush=True)
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
