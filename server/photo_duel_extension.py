"""Isolated, opt-in Photo Duel v3 endpoint. Never imported by production.
The legacy connection path delegates to the unchanged existing room server.
Run from repo root: python server/photo_duel_extension.py
"""
import asyncio
import ipaddress
import json
import os
import secrets
import time
from collections import deque
from pathlib import Path

from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed
import server as legacy
from photo_duel_staging import StagingHub
import duel_questions

VERSION = 3
TIMERS = (0, 10, 20, 30, 60)
RESUME_SECONDS = 90
FACTS = {"living", "animal", "celebrity", "edible", "household", "natural", "place", "large"} | set(duel_questions.LABELS)

class ProtocolError(ValueError):
    pass

def integer(value, allowed):
    if type(value) is not int or value not in allowed:
        raise ProtocolError("Invalid setting")
    return value

def text(value, limit=280):
    if not isinstance(value, str) or not value.strip() or len(value) > limit:
        raise ProtocolError("Invalid text")
    if any(ord(c) < 32 and c not in "\n\t" for c in value):
        raise ProtocolError("Invalid text characters")
    return value.strip()

class Room:
    def __init__(self, code, capacity, timer, target, catalog):
        self.match_id = secrets.token_hex(24)
        self.code, self.capacity, self.timer, self.target = code, capacity, timer, target
        self.catalog = catalog
        self.peers = [None] * capacity
        self.tokens = [secrets.token_urlsafe(32) for _ in range(capacity)]
        self.joined = 0
        self.images = secrets.SystemRandom().sample(list(catalog), capacity)
        self.scores = [0] * capacity
        self.current = 0
        self.round = 1
        self.started = False
        self.closed = False
        self.winner = -1
        self.pending = None
        self.chat = deque(maxlen=50)
        self.history = deque(maxlen=50)
        self.disconnected = {}
        self.deadline = None
        self.remaining = None
        self.revision = 0
        self.activity = time.monotonic()

    @property
    def paused(self):
        return bool(self.disconnected)

    @property
    def responder(self):
        return (self.current + 1) % self.capacity

    def arm(self):
        self.deadline = time.monotonic() + self.timer if self.timer else None
        self.remaining = None

    def advance(self, reason):
        self.pending = None
        self.current = (self.current + 1) % self.capacity
        self.history.append({"kind":"turn", "reason":reason, "player":self.current})
        self.arm()

    def expire(self):
        if self.started and not self.closed and not self.paused and self.deadline is not None and time.monotonic() >= self.deadline:
            self.advance("timeout")
            self.revision += 1
            return True
        return False

    def view(self, player):
        now = time.monotonic()
        left = self.remaining if self.paused else (max(0, self.deadline - now) if self.deadline is not None else None)
        return {"type":"duel_state", "protocol":VERSION, "code":self.code,
            "player":player, "capacity":self.capacity, "joined":self.joined,
            "connected":[p is not None for p in self.peers], "started":self.started,
            "paused":self.paused, "closed":self.closed, "winner":self.winner,
            "current":self.current, "responder":self.responder,
            "round":self.round, "scores":self.scores.copy(), "target":self.target,
            "timer":self.timer, "remaining_ms":int(left*1000) if left is not None else None,
            "deadline_unix_ms":int(time.time()*1000 + left*1000) if left is not None and not self.paused else None,
            "revision":self.revision, "pending":self.pending,
            "opponents":[{"player":i,"image":self.catalog[self.images[i]]["image"]} for i in range(self.capacity) if i != player and i < self.joined],
            "chat":list(self.chat), "history":list(self.history),
            "preset_questions":duel_questions.available(self, player)}

class DuelHub:
    def __init__(self):
        path = Path(__file__).resolve().parents[1]/"data/guess_picture_302/catalog.json"
        items = json.loads(path.read_text(encoding="utf-8"))["items"]
        self.catalog = {i["id"]:i for i in items if i.get("group")=="original_200" and i.get("rights_status")=="CORE_200_EXISTING_LIBRARY"}
        if len(self.catalog) != 200:
            raise RuntimeError("Exactly 200 original images required")
        self.rooms, self.bindings = {}, {}
        self.lock = asyncio.Lock()
        self.old_photo = StagingHub()

    async def send(self, ws, message):
        await ws.send(json.dumps(message, ensure_ascii=False))

    async def publish(self, room):
        room.revision += 1
        for i, peer in enumerate(room.peers):
            if peer is not None:
                try:
                    await self.send(peer, room.view(i))
                except ConnectionClosed:
                    pass

    async def reject(self, ws, message):
        await self.send(ws, {"type":"duel_error", "protocol":VERSION,"message":str(message)[:160]})

    def binding(self, ws):
        if ws not in self.bindings:
            raise ProtocolError("Not in a room")
        code, player = self.bindings[ws]
        room = self.rooms.get(code)
        if room is None or room.closed:
            raise ProtocolError("Room unavailable")
        return room, player

    async def handle(self, ws, msg):
        if type(msg.get("protocol")) is not int or msg.get("protocol") != VERSION:
            raise ProtocolError("Unsupported protocol version")
        action = msg.get("type")
        if action == "duel_hello":
            if msg.get("protocol") != VERSION:
                raise ProtocolError("Unsupported protocol version")
            return await self.send(ws, {"type":"duel_capabilities", "protocol":VERSION,"players":[2,3,4,5,6],"timers":list(TIMERS),"resume_seconds":RESUME_SECONDS,"chat":True,"voice":False})
        if action == "duel_create":
            if ws in self.bindings or len(self.rooms) >= 100:
                raise ProtocolError("Already in a room or capacity reached")
            if msg.get("protocol") != VERSION:
                raise ProtocolError("Protocol negotiation required")
            capacity=integer(msg.get("players",2),range(2,7))
            timer=integer(msg.get("timer",30),TIMERS)
            target=integer(msg.get("target",10),range(1,51))
            code=secrets.token_hex(4).upper()
            while code in self.rooms: code=secrets.token_hex(4).upper()
            room=Room(code,capacity,timer,target,self.catalog)
            self.rooms[code]=room
            room.peers[0]=ws
            room.joined=1
            self.bindings[ws]=(code,0)
            await self.send(ws,{"type":"duel_created","code":code,"token":room.tokens[0],"player":0})
            return await self.publish(room)
        if action in ("duel_join","duel_resume"):
            if ws in self.bindings:
                raise ProtocolError("Already in a room")
            code=msg.get("code")
            room=self.rooms.get(code) if isinstance(code,str) else None
            if room is None or room.closed:
                raise ProtocolError("Room unavailable")
            if action == "duel_join":
                if room.started or room.joined >= room.capacity:
                    raise ProtocolError("Room full")
                player=room.joined
                room.joined+=1
                room.peers[player]=ws
                if room.joined == room.capacity:
                    room.started=True
                    if not room.paused: room.arm()
            else:
                token=msg.get("token")
                player=next((i for i,t in enumerate(room.tokens) if isinstance(token,str) and secrets.compare_digest(t,token)),None)
                if player is None or player not in room.disconnected or time.monotonic()-room.disconnected[player] > RESUME_SECONDS:
                    raise ProtocolError("Invalid or expired resume token")
                if room.peers[player] is not None:
                    raise ProtocolError("Session already active")
                room.tokens[player]=secrets.token_urlsafe(32)
                room.peers[player]=ws
                del room.disconnected[player]
                if not room.paused and room.started and room.timer:
                    room.deadline=time.monotonic()+(room.remaining if room.remaining is not None else room.timer)
                    room.remaining=None
            self.bindings[ws]=(room.code,player)
            room.activity=time.monotonic()
            await self.send(ws,{"type":"duel_joined" if action=="duel_join" else "duel_resumed","code":room.code,"token":room.tokens[player],"player":player})
            return await self.publish(room)
        room,player=self.binding(ws)
        room.activity=time.monotonic()
        if action == "duel_sync":
            room.expire()
            return await self.publish(room)
        if action == "duel_leave":
            room.closed=True
            room.history.append({"kind":"closed","reason":"player_left"})
            room.tokens=[""]*room.capacity
            await self.publish(room)
            self.rooms.pop(room.code,None)
            for peer in room.peers:
                self.bindings.pop(peer,None)
            return
        if room.expire(): await self.publish(room)
        if action == "duel_chat":
            room.chat.append({"player":player,"text":text(msg.get("text"))})
            return await self.publish(room)
        if not room.started or room.paused:
            raise ProtocolError("Match waiting or paused")
        if action in ("duel_question","duel_preset","duel_guess","duel_pass"):
            if player != room.current or room.pending is not None:
                raise ProtocolError("Not your turn or waiting for response")
            if action == "duel_pass": room.advance("pass")
            elif action == "duel_guess":
                room.pending={"kind":"guess","text":text(msg.get("guess")),"asker":player,"responder":room.responder}
            else:
                mode="preset" if action=="duel_preset" else "text"
                question_text = text(msg.get('text')) if mode=='text' else ''
                key=msg.get("question_id") if mode=="preset" else next((key for key, labels in duel_questions.LABELS.items() if duel_questions.normalize(question_text) in [duel_questions.normalize(label) for label in labels.values()]), None)
                if mode=='text' and duel_questions.normalize(question_text) in duel_questions.state(room, player)['texts']:
                    raise ProtocolError('This question was already answered for this picture')
                if key and key in duel_questions.state(room, player)['answers']:
                    raise ProtocolError('This question was already answered for this picture')
                if mode=="preset" and (not isinstance(key,str) or key not in FACTS or key not in duel_questions.available(room, player)):
                    raise ProtocolError("Unknown preset question")
                room.pending={"kind":"question","mode":mode,"question_id":key,"text":question_text,"asker":player,"responder":room.responder}
        elif action in ("duel_reply","duel_confirm"):
            pending=room.pending
            field="answer" if action=="duel_reply" else "correct"
            expected="question" if action=="duel_reply" else "guess"
            if not pending or pending["kind"]!=expected or player!=pending["responder"] or type(msg.get(field)) is not bool:
                raise ProtocolError("Only designated opponent may reply or confirm")
            answer=msg[field]
            if expected=="question" and pending["mode"]=="preset":
                actual=self.catalog[room.images[room.current]]["facts"][pending["question_id"]]
                if answer != actual:
                    raise ProtocolError("Preset reply contradicts the photo fact")
            room.history.append({"kind":"reply" if expected=="question" else "confirmation","player":player,"asker":room.current,"text":pending["text"],"question_id":pending.get("question_id"),"answer":answer})
            if expected=='question': duel_questions.remember(room, room.current, pending, answer)
            if expected=="guess" and answer:
                room.scores[room.current]+=1
                if room.scores[room.current]>=room.target:
                    room.winner=room.current
                    room.closed=True
                    room.tokens=[""]*room.capacity
                else:
                    choices=[key for key in self.catalog if key not in room.images]
                    room.images[room.current]=secrets.choice(choices)
                    room.round+=1
            if not room.closed: room.advance("answered" if expected=="question" else "confirmed")
            else: room.pending=None
        else:
            raise ProtocolError("Unsupported Photo Duel action")
        await self.publish(room)
        if room.closed:
            self.rooms.pop(room.code,None)
            for peer in room.peers: self.bindings.pop(peer,None)

    async def disconnect(self, ws):
        binding=self.bindings.pop(ws,None)
        if binding:
            room=self.rooms.get(binding[0])
            if room and not room.closed:
                if not room.paused and room.deadline is not None:
                    room.remaining=max(0,room.deadline-time.monotonic())
                    room.deadline=None
                room.peers[binding[1]]=None
                room.disconnected[binding[1]]=time.monotonic()
                await self.publish(room)

    async def connection(self, ws):
        extension=False
        try:
            raw=await asyncio.wait_for(ws.recv(),15)
            first=json.loads(raw)
            if not isinstance(first,dict): raise ProtocolError("Expected object")
            kind=first.get("type","")
            if not isinstance(kind,str): raise ProtocolError("Invalid action")
            if not kind.startswith("duel_"):
                # Delegation occurs only on this isolated endpoint. Production code is unmodified.
                if kind.startswith("photo_"):
                    async with self.old_photo.lock: await self.old_photo.handle(ws,first)
                    return await self.old_photo.connected(ws)
                await legacy.process(ws,first)
                return await legacy.handler(ws)
            extension=True
            recent=deque()
            chat_recent=deque()
            async def message(msg):
                if not isinstance(msg,dict): raise ProtocolError("Expected object")
                now=time.monotonic()
                while recent and now-recent[0]>10: recent.popleft()
                recent.append(now)
                if len(recent)>100: raise ProtocolError("Request rate limit")
                if msg.get("type")=="duel_chat":
                    while chat_recent and now-chat_recent[0]>1: chat_recent.popleft()
                    chat_recent.append(now)
                    if len(chat_recent)>5: raise ProtocolError("Chat rate limit")
                async with self.lock: await self.handle(ws,msg)
            try: await message(first)
            except (ProtocolError,TypeError,KeyError) as exc: await self.reject(ws,exc)
            async for raw in ws:
                try:
                    if not isinstance(raw,str) or len(raw.encode("utf-8"))>8192: raise ProtocolError("Message too large")
                    await message(json.loads(raw))
                except (ValueError,TypeError,KeyError) as exc:
                    await self.reject(ws,exc)
        except (ConnectionClosed,asyncio.TimeoutError):
            pass
        except (ValueError,TypeError,KeyError) as exc:
            try: await self.reject(ws,exc)
            except ConnectionClosed: pass
        finally:
            if extension:
                async with self.lock: await self.disconnect(ws)

    async def sweep(self):
        while True:
            await asyncio.sleep(.05)
            async with self.lock:
                for code,room in list(self.rooms.items()):
                    now=time.monotonic()
                    if now-room.activity>1200 or any(now-t>RESUME_SECONDS for t in room.disconnected.values()):
                        room.closed=True
                        room.tokens=[""]*room.capacity
                        await self.publish(room)
                    elif room.expire(): await self.publish(room)
                    if room.closed:
                        self.rooms.pop(code,None)
                        for peer in room.peers: self.bindings.pop(peer,None)

async def main():
    host=os.getenv("GAMINGHUB_DUEL_HOST","127.0.0.1")
    address=ipaddress.ip_address(host)
    if not address.is_loopback and not (address.is_private and os.getenv("GAMINGHUB_DUEL_ALLOW_LAN")=="1"):
        raise SystemExit("Only loopback or explicitly authorized private LAN binds are allowed")
    hub=DuelHub()
    async with serve(hub.connection,host,int(os.getenv("GAMINGHUB_DUEL_PORT","8771")),max_size=8192,max_queue=16) as listener:
        print("LOCAL_PHOTO_DUEL_READY",listener.sockets[0].getsockname()[1],flush=True)
        await asyncio.gather(hub.sweep(),hub.old_photo.sweep(),legacy.expiry_loop())

if __name__=="__main__": asyncio.run(main())
