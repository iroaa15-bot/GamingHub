"""Opt-in loopback-only picture filters. Does not change/deploy any existing service."""
import asyncio,json,secrets
from pathlib import Path
from websockets.asyncio.server import serve
from room_codes_local import new_room_code
from photo_duel_extension import DuelHub,Room,ProtocolError,integer,TIMERS,VERSION

class FilterHub(DuelHub):
 def __init__(self):
  super().__init__()
  root=Path(__file__).resolve().parents[1]
  self.filters=json.loads((root/'data/picture_filters.json').read_text(encoding='utf-8'))
  cards=json.loads((root/'data/cards.json').read_text(encoding='utf-8'))['cards']
  from approved_content import pictures
  approved=pictures()
  for key in ('categories','items'):self.filters[key].update(approved['filters'][key])
  for item in approved['catalog']:
   if item['id'] in self.catalog:raise ValueError('Approved ID collision')
   self.catalog[item['id']]=item
  by_asset={('res://assets/generated/'+c['image']+'.webp'):self.filters['items'][c['name']] for c in cards}
  by_asset.update({item['image']:self.filters['items'][item['name']] for item in approved['catalog']})
  self.filter_items={key:by_asset[item['image']] for key,item in self.catalog.items()}
 async def send(self,ws,message):
  message=message.copy()
  if message.get('type')=='duel_capabilities':
   message.update(picture_filters=True,picture_categories=self.filters['categories'],picture_difficulties=self.filters['difficulties'])
  if message.get('type')=='duel_state' and ws in self.bindings:
   room=self.rooms.get(self.bindings[ws][0])
   message.update(picture_category=getattr(room,'picture_category','all'),picture_difficulty=getattr(room,'picture_difficulty','all'))
  await super().send(ws,message)
 async def handle(self,ws,msg):
  if msg.get('type')!='duel_create' or not any(k in msg for k in ('picture_category','picture_difficulty')):return await super().handle(ws,msg)
  if msg.get('protocol')!=VERSION or ws in self.bindings or len(self.rooms)>=100:raise ProtocolError('Invalid room creation')
  capacity=integer(msg.get('players',2),range(2,7));timer=integer(msg.get('timer',30),TIMERS);target=integer(msg.get('target',10),range(1,51))
  category=msg.get('picture_category','all');difficulty=msg.get('picture_difficulty','all')
  if not isinstance(category,str) or category not in ['all',*self.filters['categories']]:raise ProtocolError('Invalid picture category')
  if not isinstance(difficulty,str) or difficulty not in self.filters['difficulties']:raise ProtocolError('Invalid picture difficulty')
  pool={k:v for k,v in self.catalog.items() if (category=='all' or self.filter_items[k]['category']==category) and (difficulty=='all' or self.filter_items[k]['difficulty']==difficulty)}
  if len(pool)<capacity:raise ProtocolError('Not enough different pictures for the requested player count')
  code=new_room_code(self.rooms)
  room=Room(code,capacity,timer,target,pool);room.picture_category=category;room.picture_difficulty=difficulty
  self.rooms[code]=room;room.peers[0]=ws;room.joined=1;self.bindings[ws]=(code,0)
  await self.send(ws,{'type':'duel_created','code':code,'token':room.tokens[0],'player':0})
  await self.publish(room)
async def main():
 hub=FilterHub()
 async with serve(hub.connection,'127.0.0.1',8881,max_size=8192,max_queue=16):
  print('LOCAL_FILTER_HUB_READY 8881',flush=True)
  await hub.sweep()
if __name__=='__main__':asyncio.run(main())
