"""Local shared-port regression tests. Never contacts production."""
import asyncio, json, unittest
import server as app
from websockets.asyncio.server import serve
from websockets.asyncio.client import connect

class IntegrationTests(unittest.IsolatedAsyncioTestCase):
 async def asyncSetUp(self):
  self.old=app.PHOTO_DUEL_ENABLED
  app.PHOTO_DUEL_ENABLED=True
  app.photo_hub=app.StagingHub()
  self.listener=await serve(app.handler,'127.0.0.1',0)
  self.url='ws://127.0.0.1:'+str(self.listener.sockets[0].getsockname()[1])
 async def asyncTearDown(self):
  self.listener.close();await self.listener.wait_closed()
  app.PHOTO_DUEL_ENABLED=self.old
 async def receive(self,ws,kind):
  for _ in range(12):
   msg=json.loads(await asyncio.wait_for(ws.recv(),3))
   if msg['type']==kind:return msg
  self.fail('Missing '+kind)
 async def send(self,ws,**msg):await ws.send(json.dumps(msg))
 async def test_shared_port_join_turn_resume_and_original_room(self):
  async with connect(self.url) as a,connect(self.url) as b,connect(self.url) as original:
   await self.send(original,type='create')
   legacy=await self.receive(original,'room')
   self.assertTrue(legacy['code'])
   await self.send(a,type='photo_create',timer=0,target=3,reward=1)
   created=await self.receive(a,'photo_created')
   await self.send(b,type='photo_join',code=created['code'])
   await self.receive(b,'photo_joined')
   sa=await self.receive(a,'photo_state');sb=await self.receive(b,'photo_state')
   self.assertNotEqual(sa['visible_opponent_image']['id'],sb['visible_opponent_image']['id'])
   await self.send(a,type='photo_text',text='Is it alive?')
   await self.receive(b,'photo_question')
   pending=await self.receive(b,'photo_state')
   self.assertEqual(pending['question_text'],'Is it alive?')
   await self.send(b,type='photo_reply',answer=True)
   await self.receive(a,'photo_reply')
   await self.send(a,type='photo_pass')
   while (await self.receive(b,'photo_state'))['current']!=1:pass
   await a.close();await asyncio.sleep(.05)
   async with connect(self.url) as resumed:
    await self.send(resumed,type='photo_resume',code=created['code'],token=created['token'])
    result=await self.receive(resumed,'photo_resumed')
    self.assertNotEqual(result['token'],created['token'])
    await self.send(resumed,type='photo_leave')
    while not (await self.receive(resumed,'photo_state'))['closed']:pass
 async def test_voice_frames_do_not_hit_normal_button_rate_limit(self):
  import base64
  async with connect(self.url) as a,connect(self.url) as b:
   await self.send(a,type='photo_create',timer=0)
   code=(await self.receive(a,'photo_created'))['code']
   await self.send(b,type='photo_join',code=code)
   await self.receive(b,'photo_joined')
   await self.send(a,type='photo_voice_start')
   await self.receive(b,'photo_question')
   for _ in range(40):
    await self.send(a,type='photo_voice',pcm=base64.b64encode(bytes(1920)).decode())
    await self.receive(b,'photo_voice')
   await self.send(a,type='photo_sync')
   while not (await self.receive(a,'photo_state'))['pending_question']:pass
 async def test_disabled_and_cross_mode_guard(self):
  async with connect(self.url) as a:
   app.PHOTO_DUEL_ENABLED=False
   await self.send(a,type='photo_create')
   self.assertIn('not enabled',(await self.receive(a,'photo_error'))['message'])
   app.PHOTO_DUEL_ENABLED=True
   await self.send(a,type='create');await self.receive(a,'room')
   await self.send(a,type='photo_create')
   self.assertIn('Leave',(await self.receive(a,'photo_error'))['message'])

if __name__=='__main__':unittest.main()
