"""One-origin identity, admin and authenticated game service. Never auto-deployed.

Run with one worker: uvicorn identity_backend.integrated_app:app
TLS is required at the hosting proxy. DATABASE_URL and secrets stay server-only.
"""
import asyncio,os,sys
from contextlib import asynccontextmanager
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from fastapi import Request,WebSocket,WebSocketDisconnect
from fastapi.responses import Response
from websockets.exceptions import ConnectionClosed
from identity_backend.app import app,initialize
from social_rooms import SocialHub

@asynccontextmanager
async def lifespan(app):
    secret=os.environ.get('DUEL_AUTH_SECRET','')
    if len(secret)<32:raise RuntimeError('DUEL_AUTH_SECRET must be configured server-side')
    initialize()
    hub=SocialHub(secret,os.environ.get('DUEL_MODERATION_DB',':memory:'))
    app.state.hub=hub
    tasks=[asyncio.create_task(hub.sweep()),asyncio.create_task(hub.mixer())]
    try:yield
    finally:
        for task in tasks:task.cancel()
        await asyncio.gather(*tasks,return_exceptions=True)
        if hub.award_jobs:await asyncio.gather(*hub.award_jobs.values())
        hub.moderation.db.close()

app.router.lifespan_context=lifespan

class Transport:
    def __init__(self,ws):self.ws=ws;self.remote_address=(ws.client.host,ws.client.port)
    @staticmethod
    def respond(status,body):return SimpleNamespace(status=status,body=body,headers={})
    async def recv(self):
        try:return await self.ws.receive_text()
        except WebSocketDisconnect:raise ConnectionClosed(None,None)
    async def send(self,message):
        try:await self.ws.send_text(message)
        except (WebSocketDisconnect,RuntimeError):raise ConnectionClosed(None,None)
    async def close(self,code=1000,reason=''):
        try:await self.ws.close(code=code,reason=reason)
        except RuntimeError:pass
    def __aiter__(self):return self
    async def __anext__(self):
        try:return await self.recv()
        except ConnectionClosed:raise StopAsyncIteration

@app.get('/health')
@app.get('/session')
@app.get('/session/refresh')
async def room_http(request:Request):
    transport=SimpleNamespace(remote_address=(request.client.host,request.client.port),respond=Transport.respond)
    result=await app.state.hub.http(transport,SimpleNamespace(path=request.url.path,headers=request.headers))
    return Response(result.body,status_code=result.status,headers=result.headers)

@app.websocket('/')
async def room_socket(ws:WebSocket):
    transport=Transport(ws)
    hub=app.state.hub
    result=await hub.http(transport,SimpleNamespace(path='/',headers=ws.headers))
    if result is not None:
        await ws.close(code=1008);return
    await ws.accept()
    await hub.connection(transport)
