from account_rooms import AccountRooms
"""Separate authenticated Render-ready service. No production modules are edited.
TLS terminates at Render's edge; direct local tests bind loopback only.
"""
import asyncio, base64, binascii, ipaddress, json, os, signal, struct, time
from collections import deque
from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed
from photo_duel_extension import DuelHub, ProtocolError, VERSION, text, legacy
from duel_security import Sessions, Limits, Moderation

class SecureDuelHub(AccountRooms,DuelHub):
    def __init__(self, secret, database, trust_proxy=False):
        super().__init__();self.sessions=Sessions(secret);self.limits=Limits();self.moderation=Moderation(database)
        self.identities={};self.subjects={};self.voice={};self.trust_proxy=trust_proxy;self.epoch=0
    def ip(self,connection,request):
        # Forwarded headers are client input until a documented trusted-proxy
        # boundary is configured. Use the TCP peer even on Render: conservative
        # shared-edge limits are safer than a spoofable per-client limit.
        return str(connection.remote_address[0])
    async def http(self,connection,request):
        def response(status,payload):
            result=connection.respond(status,json.dumps(payload))
            result.headers["Content-Type"]="application/json"
            result.headers["Cache-Control"]="no-store"
            return result
        address=self.ip(connection,request)
        if request.path=="/health":return response(200,{"status":"ok","protocol":VERSION,"service":"gaminghub-duel-wss","authenticated":True})
        if request.headers.get("Origin") is not None:return response(403,{"error":"Native client endpoint"})
        if request.path=="/session":
            if request.headers.get("X-GamingHub-Terms")!="1":return response(403,{"error":"Terms acceptance required"})
            if not self.limits.admit((address,"session"),10,60):return response(429,{"error":"Session rate limit"})
            token,claims=self.sessions.issue()
            return response(200,{"token":token,"expires_in":self.sessions.ttl,"terms":"1"})
        if request.path!="/":return response(404,{"error":"Not found"})
        if not self.limits.admit((address,"upgrade"),40,60):return response(429,{"error":"Connection rate limit"})
        bearer=request.headers.get("Authorization","")
        try:
            if not bearer.startswith("Bearer "):raise ValueError()
            self.identities[connection]=self.sessions.verify(bearer[7:])
        except ValueError:return response(401,{"error":"Authentication required"})
        return None
    def voice_state(self,room,player):
        value=self.voice.setdefault(room.code,{"enabled":[False]*room.capacity,"epoch":0,"seq":0,"queues":[deque(maxlen=3) for _ in range(room.capacity)],"last":[-1]*room.capacity})
        return {"local_enabled":value["enabled"][player],"peer_enabled":any(v for i,v in enumerate(value["enabled"]) if i!=player),"epoch":value["epoch"],"available":room.started and not room.paused and not room.closed}
    def reset_voice(self,room):
        self.voice.pop(room.code,None)
        self.voice_state(room,0)
        # Epoch is never reused in this server process.
        self.epoch+=1
        self.voice[room.code]["epoch"]=self.epoch
    async def send(self,ws,message):
        if message.get("type")=="duel_capabilities":message={**message,"identity_accounts":bool(os.environ.get("GAMINGHUB_DATABASE_URL"))}
        message=dict(message)
        if message.get("type")=="duel_capabilities":message.update(authenticated=True,voice=True,voice_codec="pcm16/16000/mono/20ms",moderation=True)
        if message.get("type")=="duel_state":
            room=self.rooms.get(message.get("code"))
            if room:message["voice"]=self.voice_state(room,message["player"])
        return await super().send(ws,message)
    async def handle(self,ws,msg):
        if msg.get("type")=="duel_auth_bind":
            return await self.bind_account(ws,msg)
        identity=self.identities.get(ws)
        if not identity or identity["exp"]<=time.time():raise ProtocolError("Session expired")
        subject=identity["sub"]
        action=msg.get("type")
        if action in ("duel_join","duel_resume"):
            if not isinstance(msg.get("code"),str):raise ProtocolError("Invalid room code")
            owners=self.subjects.get(msg.get("code"),{})
            if action=="duel_join" and any(self.moderation.blocked(subject,other) for other in owners.values()):raise ProtocolError("Room unavailable")
            if action=="duel_resume":
                room=self.rooms.get(msg.get("code"));token=msg.get("token")
                index=next((i for i,t in enumerate(room.tokens) if isinstance(token,str) and __import__('hmac').compare_digest(t,token)),None) if room else None
                if index is None or owners.get(index)!=subject:raise ProtocolError("Resume identity mismatch")
                old_peer=room.peers[index]
                if old_peer is not None and old_peer is not ws and ws not in self.bindings:
                    # A mobile network can reconnect before the old TCP socket times
                    # out. Both the private room capability and transport identity
                    # were verified above; retire the old binding before takeover.
                    await self.disconnect(old_peer)
                    close=getattr(old_peer,'close',None)
                    if close:
                        try:await asyncio.wait_for(close(code=1012,reason='Session resumed on a new connection'),1)
                        except Exception:pass
        if action in ("duel_voice_state","duel_voice_audio","duel_block","duel_report"):
            if msg.get("protocol")!=VERSION:raise ProtocolError("Unsupported protocol")
            room,player=self.binding(ws)
            if action in ("duel_block","duel_report"):
                if not self.limits.admit((subject,"moderation"),5,60):raise ProtocolError("Report/block rate limit")
                target=msg.get("target")
                if type(target) is not int or target==player or not 0<=target<room.joined:raise ProtocolError("Invalid report target")
                owner=self.subjects[room.code][target]
                if action=="duel_report":
                    identifier=self.moderation.report(subject,owner,text(msg.get("reason")))
                    return await self.send(ws,{"type":"duel_reported","report_id":identifier})
                self.moderation.block(subject,owner)
                await self.send(ws,{"type":"duel_blocked","target":target})
                return await super().handle(ws,{"type":"duel_leave","protocol":VERSION})
            if not room.started or room.paused or room.closed:raise ProtocolError("Voice room unavailable")
            value=self.voice.setdefault(room.code,{})
            if not value:self.voice_state(room,player);value=self.voice[room.code]
            if action=="duel_voice_state":
                if type(msg.get("enabled")) is not bool:raise ProtocolError("Invalid consent")
                value["enabled"][player]=msg["enabled"]
                self.epoch+=1;value["epoch"]=self.epoch;value["seq"]=0
                for queue in value["queues"]:queue.clear()
                value["last"]=[-1]*room.capacity
                return await self.publish(room)
            if not value["enabled"][player] or msg.get("epoch")!=value["epoch"]:raise ProtocolError("Voice consent or epoch mismatch")
            seq=msg.get("seq")
            if type(seq) is not int or seq<=value["last"][player]:raise ProtocolError("Stale audio frame")
            encoded=msg.get("pcm")
            try:
                if not isinstance(encoded,str) or len(encoded)!=856:raise ValueError()
                raw=base64.b64decode(encoded,validate=True)
                if len(raw)!=640:raise ValueError()
            except (ValueError,binascii.Error):raise ProtocolError("Invalid PCM frame")
            value["last"][player]=seq;value["queues"][player].append(raw)
            return
        await super().handle(ws,msg)
        binding=self.bindings.get(ws)
        if binding:self.subjects.setdefault(binding[0],{})[binding[1]]=subject
    async def disconnect(self,ws):
        binding=self.bindings.get(ws)
        if binding:
            room=self.rooms.get(binding[0])
            if room:self.reset_voice(room)
        await super().disconnect(ws);self.identities.pop(ws,None)
        self.account_connections.pop(ws,None)
        self.public_profiles.pop(ws,None)
    async def connection(self,ws):
        extension=False
        try:
            raw=await asyncio.wait_for(ws.recv(),15)
            if not isinstance(raw,str) or len(raw.encode())>8192:raise ProtocolError("Message too large or non-text")
            first=json.loads(raw)
            if not isinstance(first,dict):raise ProtocolError("Expected object")
            kind=first.get("type","")
            if not isinstance(kind,str):raise ProtocolError("Invalid action")
            if not kind.startswith("duel_"):
                # Authentication wraps the old wire protocol without changing its implementation.
                if kind.startswith("photo_"):
                    async with self.old_photo.lock:await self.old_photo.handle(ws,first)
                    return await self.old_photo.connected(ws)
                await legacy.process(ws,first)
                return await legacy.handler(ws)
            extension=True
            limit_key=(id(ws),time.monotonic_ns())
            async def receive(msg):
                if not isinstance(msg,dict):raise ProtocolError("Expected object")
                media=msg.get("type")=="duel_voice_audio"
                limit,seconds=(80,1) if media else (100,10)
                if not self.limits.admit((limit_key,"media" if media else "messages"),limit,seconds):raise ProtocolError("Request rate limit")
                if msg.get("type")=="duel_chat" and not self.limits.admit((limit_key,"chat"),5,1):raise ProtocolError("Chat rate limit")
                async with self.lock:await self.handle(ws,msg)
            try:await receive(first)
            except (ValueError,TypeError,KeyError) as error:await self.reject(ws,error)
            async for raw in ws:
                parsed=None
                try:
                    if not isinstance(raw,str) or len(raw.encode())>8192:raise ProtocolError("Message too large")
                    parsed=json.loads(raw)
                    await receive(parsed)
                except (ValueError,TypeError,KeyError) as error:
                    if isinstance(parsed,dict) and parsed.get("type") in ("duel_voice_audio","duel_voice_state"):
                        await self.send(ws,{"type":"duel_error","scope":"voice","message":str(error)[:160]})
                    else:await self.reject(ws,error)
        except (ConnectionClosed,asyncio.TimeoutError):pass
        except (ValueError,TypeError,KeyError) as error:
            try:await self.reject(ws,error)
            except ConnectionClosed:pass
        finally:
            if extension:
                async with self.lock:await self.disconnect(ws)
            self.identities.pop(ws,None)
    async def mixer(self):
        while True:
            await asyncio.sleep(.02)
            # Close expired transports even when idle, including receive-only
            # voice and authenticated legacy connections. Never await close
            # while holding the room lock (disconnect needs that lock).
            expired=[ws for ws,claims in list(self.identities.items()) if claims["exp"]<=time.time()]
            for ws in expired:
                await ws.close(code=1008,reason="Session expired")
            async with self.lock:
                for code,value in list(self.voice.items()):
                    room=self.rooms.get(code)
                    if room is None:self.voice.pop(code,None);self.subjects.pop(code,None);continue
                    if room.paused or room.closed:continue
                    frames={i:struct.unpack("<320h",q.popleft()) for i,q in enumerate(value["queues"]) if q and value["enabled"][i]}
                    if not frames:continue
                    value["seq"]+=1
                    for receiver,ws in enumerate(room.peers):
                        sources=[frame for sender,frame in frames.items() if sender!=receiver]
                        if ws is None or not value["enabled"][receiver] or not sources:continue
                        # One mixed stream per recipient preserves the original native jitter-buffer API.
                        mixed=struct.pack("<320h",*(max(-32768,min(32767,int(sum(samples)/len(samples)))) for samples in zip(*sources)))
                        try:await self.send(ws,{"type":"duel_voice_audio","epoch":value["epoch"],"seq":value["seq"],"pcm":base64.b64encode(mixed).decode()})
                        except ConnectionClosed:pass

async def main():
    secret=os.environ.get("DUEL_AUTH_SECRET","")
    hub=SecureDuelHub(secret,os.environ.get("DUEL_MODERATION_DB","/tmp/gaminghub-duel-reports.sqlite"),trust_proxy=os.environ.get("RENDER")=="true")
    host="0.0.0.0" if os.environ.get("RENDER")=="true" else "127.0.0.1"
    stop=asyncio.Event()
    for sig in (signal.SIGINT,signal.SIGTERM):
        try:asyncio.get_running_loop().add_signal_handler(sig,stop.set)
        except (NotImplementedError,RuntimeError):pass
    async with serve(hub.connection,host,int(os.environ.get("PORT","8772")),process_request=hub.http,max_size=8192,max_queue=32,compression=None,ping_interval=20,ping_timeout=20) as listener:
        print("SECURE_DUEL_READY",listener.sockets[0].getsockname()[1],flush=True)
        tasks=[asyncio.create_task(coro) for coro in [hub.sweep(),hub.old_photo.sweep(),legacy.expiry_loop(),hub.mixer()]]
        try:await stop.wait()
        finally:
            for task in tasks:task.cancel()
            await asyncio.gather(*tasks,return_exceptions=True)
            hub.moderation.db.close()

if __name__=="__main__":asyncio.run(main())
