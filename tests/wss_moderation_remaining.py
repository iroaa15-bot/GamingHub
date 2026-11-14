"""Remaining moderation authorization and generic flood checks only."""
import asyncio,json,secrets,sys,tempfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from secure_duel_service import SecureDuelHub
from websockets.asyncio.server import serve
from websockets.asyncio.client import connect
async def run():
 results={}
 with tempfile.TemporaryDirectory() as folder:
  h=SecureDuelHub(secrets.token_urlsafe(48),str(Path(folder)/'db'))
  async with serve(h.connection,'127.0.0.1',0,process_request=h.http,max_size=8192) as srv:
   url='ws://127.0.0.1:'+str(srv.sockets[0].getsockname()[1]);clients=[]
   async def client():
    w=await connect(url,additional_headers={'Authorization':'Bearer '+h.sessions.issue()[0]});clients.append(w);return w
   async def send(w,t,**kw):await w.send(json.dumps(dict(type=t,protocol=3,**kw)))
   async def recv(w,t):
    async with asyncio.timeout(4):
     while True:
      m=json.loads(await w.recv())
      if m['type']==t:return m
   a=await client();b=await client();outsider=await client()
   try:
    await send(a,'duel_create',players=2,timer=0);created=await recv(a,'duel_created');code=created['code']
    await send(b,'duel_join',code=code);await recv(b,'duel_joined')
    await send(outsider,'duel_report',target=0,reason='not a member')
    results['outsider_report_rejected']='Not in a room' in (await recv(outsider,'duel_error'))['message']
    await send(a,'duel_report',target=0,reason='self');selferr=await recv(a,'duel_error')
    await send(a,'duel_block',target=5);rangeerr=await recv(a,'duel_error')
    results['invalid_moderation_targets_rejected']=all('Invalid report target' in m['message'] for m in (selferr,rangeerr))
    results['invalid_reports_not_stored']=h.moderation.db.execute('SELECT count(*) FROM reports').fetchone()[0]==0
    for i in range(101):await send(outsider,'duel_hello')
    err=await recv(outsider,'duel_error');results['generic_message_limit']='Request rate limit' in err['message']
    # Bypass only the already-proven session-issue cap: use issuer internally,
    # but exercise all room moderation operations over real sockets.
    for i in range(4):
     await send(a,'duel_report',target=1,reason='pending review '+str(i));m=await recv(a,'duel_reported' if i<3 else 'duel_error')
    results['moderation_rate_limit']='rate limit' in m.get('message','')
   finally:await asyncio.gather(*(w.close() for w in clients))
  h.moderation.db.close()
 payload={'checks':results,'passed':all(results.values()),'scope':'loopback real WebSocket; no deployment'}
 print(json.dumps(payload,indent=2));return 0 if payload['passed'] else 1
if __name__=='__main__':sys.exit(asyncio.run(run()))
