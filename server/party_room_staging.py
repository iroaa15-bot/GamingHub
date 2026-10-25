"""Party Room isolated staging WebSocket transport. Not used by production."""
import asyncio
import json
import os
import secrets
import time
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
                await send(peer, {"type": "party.state", "state": room.view(member_id)})
            except Exception:
                pass


async def handler(ws):
    identity = None
    last_chat = 0.0
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
                    clients[identity] = ws
                    if old is not None and old is not ws:
                        await old.close()
                    await send(ws, {"type": "party.auth", "code": code, "player_id": player, "resume_token": room.members[player].token})
                else:
                    if identity is None:
                        raise PartyError("authentication_required")
                    if clients.get(identity) is not ws:raise PartyError("session_replaced")
                    room = rooms[identity[0]]
                    player = identity[1]
                    if action == "party.ready":
                        room.ready(player, message.get("ready") is True)
                    elif action == "party.start":
                        room.start(player)
                    elif action == "party.submit":
                        room.submit(player, message.get("answer"), str(message.get("request_id", "")))
                    elif action == "party.complete":
                        room.complete(player)
                    elif action == "party.approve":
                        room.approve(player,str(message.get('player_id','')))
                    elif action == "party.vote":
                        room.vote(player,message.get('option'))
                    elif action == "party.finish_votes":
                        if player!=room.host_id:raise PartyError('host_only')
                        room.finish_votes()
                    elif action == "party.chat":
                        text=message.get('text')
                        if not isinstance(text,str) or not 0<len(text.strip())<=280:raise PartyError('invalid_chat')
                        now=asyncio.get_running_loop().time()
                        if now-last_chat<0.8:raise PartyError('chat_rate_limit')
                        last_chat=now
                        for pid in room.members:
                            peer=clients.get((room.code,pid))
                            if peer is not None:await send(peer,{'type':'party.chat','name':room.members[player].display_name,'text':text.strip()})
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
    async def clock():
        while True:
            for room in list(rooms.values()):
                before=room.revision
                room.tick()
                if room.revision!=before:await publish(room)
                if not any(m.connected for m in room.members.values()) and all(m.disconnected_at is not None and time.monotonic()-m.disconnected_at>90 for m in room.members.values()):rooms.pop(room.code,None)
            await asyncio.sleep(0.5)
    async with serve(handler, host, port, max_size=16384):
        task=asyncio.create_task(clock())
        print(f"Party Room staging on {host}:{port}", flush=True)
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
