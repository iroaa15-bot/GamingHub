import asyncio,contextlib,json,secrets,sys,tempfile
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from secure_duel_service import SecureDuelHub
from websockets.asyncio.server import serve
from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosed,InvalidStatus
async def run():
 r={}
 with tempfile.TemporaryDirectory() as folder:
  hub=SecureDuelHub(secrets.token_urlsafe(48),str(Path(folder)/'reports.sqlite'),True)
  r['spoofed_forwarded_header_ignored']=hub.ip(SimpleNamespace(remote_address=('127.0.0.1',1)),SimpleNamespace(headers={'X-Forwarded-For':'1.2.3.4,5.6.7.8'}))=='127.0.0.1'
  async with serve(hub.connection,'127.0.0.1',0,process_request=hub.http,max_size=8192,compression=None) as server:
   url='ws://127.0.0.1:'+str(server.sockets[0].getsockname()[1])
   async def client(token=None):
    token=token or hub.sessions.issue()[0]
    return await connect(url,additional_headers={'Authorization':'Bearer '+token}),token
   async def recv(ws,kind):
    async with asyncio.timeout(4):
     while True:
      m=json.loads(await ws.recv())
      if m['type']==kind:return m
   async def send(ws,kind,**kw):await ws.send(json.dumps(dict(type=kind,protocol=3,**kw)))
   try:
    await client('invalid');r['invalid_token_401']=False
   except InvalidStatus as e:r['invalid_token_401']=e.response.status_code==401
   a,token=await client();b,_=await client();c,_=await client()
   try:
    await send(a,'duel_create',players=2,timer=20);created=await recv(a,'duel_created');code=created['code']
    await send(b,'duel_join',code=code);await recv(b,'duel_joined')
    await send(c,'duel_chat',text='unauthorized');r['membership']='Not in a room' in (await recv(c,'duel_error'))['message']
    await send(b,'duel_pass');r['turn_ownership']='Not your turn' in (await recv(b,'duel_error'))['message']
    await send(c,'duel_resume',code=code,token=created['token']);r['identity']='identity' in (await recv(c,'duel_error'))['message']
    await a.close()
    for _ in range(100):
     if hub.rooms[code].paused:break
     await asyncio.sleep(.01)
    a,_=await client(token);await send(a,'duel_resume',code=code,token=created['token']);res=await recv(a,'duel_resumed');state=await recv(a,'duel_state')
    r['real_reconnect']=res['player']==0 and res['token']!=created['token'] and not state['paused'] and state['timer']==20
    for payload in ('{','[]',json.dumps(dict(type='duel_join',protocol=3,code=[]))):
     await c.send(payload);await recv(c,'duel_error')
    await send(c,'duel_hello');r['malformed_recovery']=bool(await recv(c,'duel_capabilities'))
    for i in range(7):await send(b,'duel_chat',text='limit '+str(i))
    errors=[(await recv(b,'duel_error'))['message'] for _ in range(2)]
    r['chat_limit']=all('rate limit' in e for e in errors)
    for claims in hub.identities.values():claims['exp']=0
    mixer=asyncio.create_task(hub.mixer())
    try:
     async with asyncio.timeout(4):
      while True:await c.recv()
    except ConnectionClosed as e:r['idle_expiry']=e.rcvd.code==1008
    finally:
     mixer.cancel()
     with contextlib.suppress(asyncio.CancelledError):await mixer
   finally:await asyncio.gather(a.close(),b.close(),c.close())
   ws,_=await client();await ws.send(b'{"type":"duel_hello","protocol":3}');r['binary_first_frame']='non-text' in (await recv(ws,'duel_error'))['message'];await ws.close()
   ws,_=await client();await ws.send('x'*8193)
   try:await ws.recv();r['oversized']=False
   except ConnectionClosed as e:r['oversized']=e.rcvd.code==1009
   await ws.close()
  hub.moderation.db.close()
 print(json.dumps(dict(checks=r,passed=all(r.values()),scope='Real loopback sockets; not Android/public WSS'),indent=2))
 return 0 if all(r.values()) else 1
if __name__=='__main__':sys.exit(asyncio.run(run()))
