"""Authenticated loopback composition of existing security/mixer and agreement protocol.
No production entry point, configuration or native audio engine is changed.
"""
import asyncio,base64,binascii,os,secrets,time
from websockets.asyncio.server import serve
from photo_duel_agreement_local import AgreementHub
from secure_duel_service import SecureDuelHub
from photo_duel_extension import ProtocolError,VERSION

class SecureAgreementHub(SecureDuelHub,AgreementHub):
 membership_voice=True
 async def send(self,ws,message):
  if message.get('type')=='duel_capabilities':message={**message,'session_refresh':True}
  return await super().send(ws,message)
 def voice_state(self,room,player):
  result=super().voice_state(room,player)
  if getattr(room,'agreement',False):result['available']=not room.paused and not room.closed
  return result
 async def handle(self,ws,msg):
  identity=self.identities.get(ws)
  if not identity or identity['exp']<=time.time():raise ProtocolError('Session expired')
  kind=msg.get('type')
  if kind=='duel_session_refresh':
   if msg.get('protocol')!=VERSION:raise ProtocolError('Unsupported protocol')
   try:claims=self.sessions.verify(msg.get('token'))
   except ValueError:raise ProtocolError('Invalid refresh token')
   if claims['sub']!=identity['sub']:raise ProtocolError('Session identity mismatch')
   self.identities[ws]=claims
   return await self.send(ws,{'type':'duel_session_refreshed'})
  binding=self.bindings.get(ws);room=self.rooms.get(binding[0]) if binding else None
  if getattr(room,'agreement',False) and kind in ('duel_voice_state','duel_voice_audio'):
   if msg.get('protocol')!=VERSION:raise ProtocolError('Unsupported protocol')
   room,player=self.binding(ws)
   if room.paused:raise ProtocolError('Voice paused until room reconnects')
   if room.primary_mode!='voice':raise ProtocolError('Voice is not the agreed primary mode')
   room.activity=time.monotonic()
   self.voice_state(room,player);value=self.voice[room.code]
   if kind=='duel_voice_state':
    if type(msg.get('enabled')) is not bool:raise ProtocolError('Invalid consent')
    value['enabled'][player]=msg['enabled'];self.epoch+=1;value['epoch']=self.epoch;value['seq']=0
    for queue in value['queues']:queue.clear()
    value['last']=[-1]*room.capacity
    return await self.publish(room)
   if not value['enabled'][player] or msg.get('epoch')!=value['epoch']:raise ProtocolError('Voice consent or epoch mismatch')
   seq=msg.get('seq');encoded=msg.get('pcm')
   if type(seq) is not int or seq<=value['last'][player]:raise ProtocolError('Stale audio frame')
   try:
    if not isinstance(encoded,str) or len(encoded)!=856:raise ValueError()
    raw=base64.b64decode(encoded,validate=True)
    if len(raw)!=640:raise ValueError()
   except (ValueError,binascii.Error):raise ProtocolError('Invalid PCM frame')
   value['last'][player]=seq;value['queues'][player].append(raw)
   return
  prior_mode=getattr(room,'primary_mode',None)
  result=await super().handle(ws,msg)
  if room and prior_mode=='voice' and room.primary_mode!='voice':
   self.reset_voice(room);await self.publish(room)
  return result
 async def _membership_presence(self):
  while True:
   await asyncio.sleep(5)
   async with self.lock:
    for room in self.rooms.values():
     if getattr(room,'agreement',False) and not room.closed and not room.paused and any(peer is not None for peer in room.peers):room.activity=time.monotonic()
 async def sweep(self):
  presence=asyncio.create_task(self._membership_presence())
  try:await super().sweep()
  finally:
   presence.cancel();await asyncio.gather(presence,return_exceptions=True)
 async def http(self,connection,request):
  if request.path!='/session/refresh':return await super().http(connection,request)
  status=200
  try:
   if request.headers.get('Origin') is not None or request.headers.get('X-GamingHub-Terms')!='1':raise ValueError()
   if not self.limits.admit((self.ip(connection,request),'renew'),10,60):status=429;raise ValueError()
   bearer=request.headers.get('Authorization','')
   if not bearer.startswith('Bearer '):raise ValueError()
   claims=self.sessions.verify(bearer[7:]);claims['exp']=int(time.time())+self.sessions.ttl
   from duel_security import encode
   import hmac,json
   payload=encode(json.dumps(claims,separators=(',',':')).encode())
   token=payload+'.'+encode(hmac.digest(self.sessions.secret,payload.encode(),'sha256'))
   body={'token':token,'expires_in':self.sessions.ttl}
  except ValueError:
   status=401 if status==200 else status;body={'error':'Renewal denied'}
  import json
  response=connection.respond(status,json.dumps(body));response.headers['Content-Type']='application/json';response.headers['Cache-Control']='no-store'
  return response

async def main():
 # Ephemeral local secret only: never printed or used as a production credential.
 hub=SecureAgreementHub(secrets.token_urlsafe(48),':memory:')
 async with serve(hub.connection,'127.0.0.1',8883,process_request=hub.http,max_size=8192,max_queue=32,compression=None,ping_interval=20,ping_timeout=20):
  print('SECURE_AGREEMENT_LOCAL_READY 8883',flush=True)
  tasks=[asyncio.create_task(hub.sweep()),asyncio.create_task(hub.mixer())]
  try:await asyncio.Event().wait()
  finally:
   for task in tasks:task.cancel()
   await asyncio.gather(*tasks,return_exceptions=True);hub.moderation.db.close()
if __name__=='__main__':asyncio.run(main())
