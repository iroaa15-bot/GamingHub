"""Loopback-only opt-in agreement flow; production and default duel rooms unchanged."""
import asyncio,secrets,time
from websockets.asyncio.server import serve
from photo_duel_filters_local import FilterHub
from photo_duel_extension import Room,ProtocolError,VERSION,integer,text,RESUME_SECONDS

class AgreementHub(FilterHub):
 async def send(self,ws,message):
  message=message.copy()
  if message.get('type')=='duel_capabilities':
   message.update(room_agreement=True,primary_modes=['text','tap'],voice=False)
  if message.get('type')=='duel_state' and ws in self.bindings:
   room=self.rooms.get(self.bindings[ws][0])
   if getattr(room,'agreement',False):
    message.update(room_agreement=True,config_revision=room.config_revision,primary_mode=room.primary_mode,confirmed=room.confirmed.copy(),host=0)
    if not room.started: message.update(opponents=[],preset_questions=[])
  await super().send(ws,message)
 def pool(self,category,difficulty):
  if category not in ['all',*self.filters['categories']] or difficulty not in self.filters['difficulties']:raise ProtocolError('Invalid picture selection')
  return {k:v for k,v in self.catalog.items() if (category=='all' or self.filter_items[k]['category']==category) and (difficulty=='all' or self.filter_items[k]['difficulty']==difficulty)}
 async def handle(self,ws,msg):
  if type(msg.get('protocol')) is not int or msg['protocol']!=VERSION:raise ProtocolError('Unsupported protocol version')
  action=msg.get('type')
  if action=='duel_create' and msg.get('room_agreement') is True:
   difficulty=msg.get('picture_difficulty')
   if difficulty not in ('easy','medium','hard'):raise ProtocolError('Choose one difficulty before creating a room')
   await super().handle(ws,{**msg,'picture_category':'all'})
   room,_=self.binding(ws);room.agreement=True;room.config_revision=1;room.primary_mode='tap';room.confirmed=[False]*room.capacity
   return await self.publish(room)
  if action=='duel_join' and isinstance(msg.get('code'),str):
   room=self.rooms.get(msg['code'])
   if getattr(room,'agreement',False):
    if ws in self.bindings or room.started or room.closed or room.joined>=room.capacity:raise ProtocolError('Room unavailable')
    player=room.joined;room.joined+=1;room.peers[player]=ws;room.confirmed=[False]*room.capacity
    self.bindings[ws]=(room.code,player);room.activity=time.monotonic()
    await self.send(ws,{'type':'duel_joined','code':room.code,'player':player,'token':room.tokens[player]})
    return await self.publish(room)
  bound=self.bindings.get(ws);room=self.rooms.get(bound[0]) if bound else None
  if not getattr(room,'agreement',False):return await super().handle(ws,msg)
  room,player=self.binding(ws);room.activity=time.monotonic()
  if action=='duel_propose':
   if room.started or player!=0:raise ProtocolError('Only the host may propose before start')
   category=msg.get('picture_category');mode=msg.get('primary_mode')
   if not isinstance(category,str) or not isinstance(mode,str) or mode not in ('text','tap'):raise ProtocolError('Mode unavailable; voice requires a voice-capable service')
   pool=self.pool(category,room.picture_difficulty)
   if len(pool)<=room.capacity:raise ProtocolError('Need one spare distinct picture for score and reveal rounds')
   if category!=room.picture_category or mode!=room.primary_mode:
    room.catalog=pool;room.images=secrets.SystemRandom().sample(list(pool),room.capacity)
    room.picture_category=category;room.primary_mode=mode;room.config_revision+=1;room.confirmed=[False]*room.capacity
   return await self.publish(room)
  if action=='duel_accept':
   if room.started or type(msg.get('config_revision')) is not int or msg['config_revision']!=room.config_revision or msg.get('picture_difficulty')!=room.picture_difficulty:raise ProtocolError('Review and accept the current room difficulty and configuration')
   room.confirmed[player]=True
   return await self.publish(room)
  if action=='duel_start':
   if player!=0 or room.started or room.paused or room.joined!=room.capacity or not all(room.confirmed) or not all(room.peers):raise ProtocolError('All configured players must confirm and be connected')
   if len(room.catalog)<room.capacity:raise ProtocolError('Not enough pictures')
   room.started=True;room.arm()
   return await self.publish(room)
  if room.started:
   if room.expire():await self.publish(room)
   if action=='duel_confirm':
    pending=room.pending
    if room.paused or not pending or pending['kind']!='guess' or pending['responder']!=player or type(msg.get('correct')) is not bool:raise ProtocolError('Only designated opponent may confirm')
    correct=msg['correct']
    room.history.append({'kind':'confirmation','player':player,'asker':room.current,'text':pending['text'],'question_id':None,'answer':correct})
    if correct:
     room.scores[room.current]+=1
     if room.scores[room.current]>=room.target:
      room.winner=room.current;room.closed=True;room.tokens=['']*room.capacity
     else:
      room.images[room.current]=secrets.choice([key for key in room.catalog if key not in room.images]);room.round+=1
    if not room.closed:room.advance('confirmed')
    else:room.pending=None
    await self.publish(room)
    if room.closed:
     self.rooms.pop(room.code,None)
     for peer in room.peers:self.bindings.pop(peer,None)
    return
   if action=='duel_question' and room.primary_mode!='text':raise ProtocolError('Text questions are not the agreed mode')
   if action=='duel_preset' and room.primary_mode!='tap':raise ProtocolError('Preset questions are not the agreed mode')
   if action=='duel_reply' and room.primary_mode=='text':raise ProtocolError('Use the agreed text answer control')
   if action=='duel_text_reply':
    pending=room.pending
    if room.paused or not pending or pending['kind']!='question' or pending['responder']!=player or room.primary_mode!='text':raise ProtocolError('Only the designated respondent may answer')
    answer=text(msg.get('text'))
    room.history.append({'kind':'text_reply','player':player,'asker':room.current,'text':pending['text'],'answer_text':answer})
    room.advance('answered');return await self.publish(room)
  return await super().handle(ws,msg)

async def main():
 hub=AgreementHub()
 async with serve(hub.connection,'127.0.0.1',8882,max_size=8192,max_queue=16):
  print('LOCAL_AGREEMENT_HUB_READY 8882',flush=True)
  await hub.sweep()
if __name__=='__main__':asyncio.run(main())
