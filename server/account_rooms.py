"""Optional account binding for all v3 rooms; transport guests remain independent.

Rewards derive only from authoritative completed rooms. Transient DB failure
queues a bounded, idempotent retry without delaying gameplay or voice packets.
"""
import asyncio
import os
import time
import logging
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))

class AccountRooms:
    def __init__(self,*args,**kwargs):
        self.account_connections={}
        self.public_profiles={}
        self.award_jobs={}
        super().__init__(*args,**kwargs)

    async def bind_account(self,ws,msg):
        self.account_connections.pop(ws,None)
        self.public_profiles.pop(ws,None)
        identity=self.identities.get(ws)
        ok=False
        if identity and identity['exp']>time.time() and msg.get('protocol')==3 and os.environ.get('GAMINGHUB_DATABASE_URL'):
            try:
                from identity_backend.session_bindings import verify_session
                bound=await asyncio.wait_for(asyncio.to_thread(verify_session,os.environ['GAMINGHUB_DATABASE_URL'],msg.get('access_token')),4)
                if bound:
                    self.account_connections[ws]=bound.user_id;ok=True
                    self.public_profiles[ws]={"display_name":bound.display_name,"avatar_url":bound.avatar_url}
            except Exception:
                logging.getLogger(__name__).warning('Account binding unavailable')
        await self.send(ws,{'type':'duel_auth_bound','ok':ok})

    async def send(self,ws,message):
        if message.get('type')=='duel_state':
            room=self.rooms.get(message.get('code'))
            if room:
                message={**message,'profiles':[self.public_profiles.get(peer,{}) if peer else {} for peer in room.peers]}
        return await super().send(ws,message)

    def reward_intent(self,room):
        complete=getattr(room,'match_finished',False) or (room.closed and room.winner>=0 and room.scores[room.winner]>=room.target)
        if not complete or not room.started or room.paused:return None
        highest=max(room.scores)
        leaders=[i for i,score in enumerate(room.scores) if score==highest]
        if highest<=0 or len(leaders)!=1:return None
        winner=leaders[0]
        account=self.account_connections.get(room.peers[winner])
        if not account:return None
        return room.match_id,account

    async def publish(self,room):
        complete=getattr(room,'match_finished',False) or room.closed
        if complete and not getattr(room,'account_reward_checked',False):
            room.account_reward_checked=True
            intent=self.reward_intent(room)
            if intent and len(self.award_jobs)<1000:
                task=asyncio.create_task(self._award(intent))
                self.award_jobs[intent]=task
                task.add_done_callback(lambda done:self.award_jobs.pop(intent,None))
        return await super().publish(room)

    @staticmethod
    def persist_award(intent):
        import psycopg
        with psycopg.connect(os.environ['GAMINGHUB_DATABASE_URL'],connect_timeout=3) as db:
            db.execute('''CREATE TABLE IF NOT EXISTS identity_awards (
                match_id TEXT NOT NULL,user_id TEXT NOT NULL REFERENCES identity_users(id),
                points INTEGER NOT NULL,PRIMARY KEY(match_id,user_id))''')
            row=db.execute('''INSERT INTO identity_awards VALUES (%s,%s,10)
                ON CONFLICT DO NOTHING RETURNING points''',intent).fetchone()
            if row:db.execute('UPDATE identity_users SET points=points+10 WHERE id=%s',(intent[1],))
            db.commit()
        return bool(row)

    async def _award(self,intent):
        for delay in (0,2,10,30):
            if delay:await asyncio.sleep(delay)
            try:
                await asyncio.to_thread(self.persist_award,intent)
                return
            except Exception:
                logging.getLogger(__name__).warning('Win award pending; retrying without blocking gameplay')
        logging.getLogger(__name__).error('Win award could not be saved')
