import sys,asyncio,secrets,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from shared_quiz_local import SharedQuizHub
class Peer:
 async def send(self,message):pass
async def run():
 h=SharedQuizHub(secrets.token_urlsafe(48),':memory:')
 try:
  for game in ('1','6'):
   a,b=Peer(),Peer()
   for p in (a,b):
    h.identities[p]=h.sessions.issue()[1]
    await h.handle(p,dict(type='duel_hello',protocol=3,game_id=game))
   await h.handle(a,dict(type='duel_quiz_create',protocol=3,game_id=game,players=2,timer=30,rounds=1,difficulty='easy'))
   room,_=h.binding(a);assert len(room.code)==6 and room.code.isascii() and room.code.isdecimal()
   await h.handle(b,dict(type='duel_join',protocol=3,code=room.code));assert h.binding(b)[0] is room
   print('NUMERIC_ROOM_CREATE_JOIN',game,True)
 finally:h.moderation.db.close()
asyncio.run(run())
