"""Real loopback WebSocket transport: six clients, all 15 rounds, chat and resume."""
import asyncio,json,unittest
from websockets.asyncio.server import serve
from websockets.asyncio.client import connect
from server import party_room_staging as service
from server.party_room_engine import ROUND_SEQUENCE
class PartySocketTests(unittest.IsolatedAsyncioTestCase):
 async def test_six_clients_fifteen_rounds_and_reconnection(self):
  service.rooms.clear();service.clients.clear();clients=[];auth=[]
  async with serve(service.handler,'127.0.0.1',0,max_size=16384) as server:
   url='ws://127.0.0.1:'+str(server.sockets[0].getsockname()[1])
   async def until(ws,predicate):
    for _ in range(300):
     msg=json.loads(await asyncio.wait_for(ws.recv(),5))
     self.assertNotEqual(msg['type'],'party.error',msg)
     if predicate(msg):return msg
    self.fail('too many stale messages')
   try:
    for i in range(6):
     ws=await connect(url);clients.append(ws)
     await ws.send(json.dumps({'type':'party.create' if i==0 else 'party.join','name':'Player '+str(i),'code':auth[0]['code'] if auth else ''}))
     auth.append(await until(ws,lambda m:m['type']=='party.auth'))
     await until(ws,lambda m:m['type']=='party.state' and len(m['state']['members'])==i+1)
    code=auth[0]['code'];room=service.rooms[code]
    async def action(i,message):
     revision=room.revision
     await clients[i].send(json.dumps(message))
     return await until(clients[i],lambda m:m['type']=='party.state' and m['state']['revision']>revision)
    for i in range(6):await action(i,{'type':'party.ready','ready':True})
    await action(0,{'type':'party.start'})
    await clients[1].send(json.dumps({'type':'party.chat','text':'hello friends'}))
    chat=await until(clients[0],lambda m:m['type']=='party.chat');self.assertEqual(chat['text'],'hello friends')
    # Replace an active connection: the old finalizer must not mark the new peer disconnected.
    old=clients[5];clients[5]=await connect(url)
    await clients[5].send(json.dumps({'type':'party.reconnect','code':code,'player_id':auth[5]['player_id'],'resume_token':auth[5]['resume_token']}))
    fresh=await until(clients[5],lambda m:m['type']=='party.auth')
    self.assertNotEqual(auth[5]['resume_token'],fresh['resume_token'])
    await until(clients[5],lambda m:m['type']=='party.state')
    self.assertTrue(room.members[auth[5]['player_id']].connected)
    await old.close()
    for round_no,game in enumerate(ROUND_SEQUENCE):
     for i in range(6):
      answer={'pass_the_bomb':['banana','bear','bread','bee','ball','boat'][i],'whos_most_likely':auth[1]['player_id'],'odd_one_out':'B','crazy_emoji':'الملك الأسد','fake_it':'كوكب '+str(i),'truth_or_dare':'truth','draw_disaster':'[[[0.1,0.1],[0.8,0.8]]]','secret_mission':'done'}[game]
      await action(i,{'type':'party.submit','answer':answer,'request_id':str(round_no)+'-'+str(i)})
      if game=='truth_or_dare':await action(i,{'type':'party.complete'})
     await action(0,{'type':'party.reveal'})
     if room.phase=='voting':
      for i in range(6):
       options=room.view(auth[i]['player_id'])['reveal']['options']
       await action(i,{'type':'party.vote','option':next(iter(options))})
     if game in ('truth_or_dare','secret_mission'):
      for i in range(6):await action(0,{'type':'party.approve','player_id':auth[i]['player_id']})
     state=await action(0,{'type':'party.next'})
    self.assertEqual(state['state']['phase'],'results')
    self.assertEqual(state['state']['round_index'],15)
    self.assertEqual(len(state['state']['scores']),6)
   finally:
    for ws in clients:await ws.close()
  service.rooms.clear();service.clients.clear()
if __name__=='__main__':unittest.main()
