import pytest
from identity_backend.session_bindings import BoundIdentity, SessionBindings, verify_session
from identity_backend.app import initialize, app
from fastapi.testclient import TestClient
import os

def test_session_binding_from_database():
    initialize()
    client=TestClient(app)
    response=client.post("/api/auth/guest")
    assert response.status_code==201
    token=response.json()["access_token"]
    identity=verify_session(os.environ["GAMINGHUB_DATABASE_URL"],token)
    assert identity is not None
    socket=object()
    bindings=SessionBindings()
    with pytest.raises(ValueError):
        bindings.bind_verified(socket,"client-claimed-id")
    bindings.bind_verified(socket,identity)
    assert bindings.account_for(socket)==identity.user_id
    bindings.disconnect(socket)
    assert bindings.account_for(socket) is None
    assert verify_session(os.environ["GAMINGHUB_DATABASE_URL"],"not-a-token") is None

def test_websocket_auth_bind_with_real_postgres(monkeypatch):
    import asyncio, json
    from websockets.asyncio.server import serve
    from websockets.asyncio.client import connect
    import sys
    from pathlib import Path
    sys.path.insert(0,str(Path(__file__).resolve().parents[1] / "server"))
    import server as room_server

    initialize()
    client=TestClient(app)
    token=client.post("/api/auth/guest").json()["access_token"]
    monkeypatch.setenv("GAMINGHUB_DATABASE_URL",os.environ["GAMINGHUB_DATABASE_URL"])

    async def exercise():
        listener=await serve(room_server.handler,"127.0.0.1",0)
        port=listener.sockets[0].getsockname()[1]
        try:
            async with connect(f"ws://127.0.0.1:{port}") as socket:
                await socket.send(json.dumps({"type":"auth_bind","access_token":token}))
                reply=json.loads(await asyncio.wait_for(socket.recv(),timeout=3))
                assert reply=={"type":"auth_bound","ok":True}
                assert room_server.verified_accounts
                await socket.send(json.dumps({"type":"ping","id":7}))
                assert json.loads(await asyncio.wait_for(socket.recv(),timeout=3))=={"type":"pong","id":7}
            await asyncio.sleep(0.1)
            assert not room_server.verified_accounts
        finally:
            listener.close()
            await listener.wait_closed()
    asyncio.run(exercise())
