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


def test_server_authoritative_win_awards_once(monkeypatch):
    """The room server, not the Android client, awards verified winner points."""
    import sys
    import psycopg
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "server"))
    import server as room_server

    initialize()
    client = TestClient(app)
    token = client.post("/api/auth/guest").json()["access_token"]
    identity = verify_session(os.environ["GAMINGHUB_DATABASE_URL"], token)
    assert identity is not None
    winner_connection = object()
    loser_connection = object()
    room = room_server.Room(code="CIWINROOM", players=[winner_connection, loser_connection])
    room.started_at = 123456.789
    room_server.verified_accounts[winner_connection] = identity.user_id
    try:
        assert room_server.persist_verified_win(room, 0) is True
        assert room_server.persist_verified_win(room, 0) is False
        assert room_server.persist_verified_win(room, -1) is False
        with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
            row = db.execute("SELECT points FROM identity_users WHERE id=%s", (identity.user_id,)).fetchone()
            assert row == (10,)
            awards = db.execute("SELECT count(*) FROM identity_awards WHERE user_id=%s", (identity.user_id,)).fetchone()
            assert awards == (1,)
    finally:
        room_server.verified_accounts.pop(winner_connection, None)


def test_authenticated_websocket_match_awards_winner_end_to_end():
    """Real WebSockets + PostgreSQL: authenticated guess, finished event, profile points."""
    import asyncio
    import json
    import sys
    from pathlib import Path
    from websockets.asyncio.server import serve
    from websockets.asyncio.client import connect

    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "server"))
    import server as room_server

    initialize()
    api = TestClient(app)
    registration = api.post("/api/auth/guest")
    assert registration.status_code == 201
    token = registration.json()["access_token"]
    room_server.rooms.clear()
    room_server.connections.clear()
    room_server.waiting.clear()
    room_server.verified_accounts.clear()

    async def recv(ws):
        return json.loads(await asyncio.wait_for(ws.recv(), timeout=8))

    async def send(ws, **data):
        await ws.send(json.dumps(data))

    async def run_match():
        listener = await serve(room_server.handler, "127.0.0.1", 0)
        port = listener.sockets[0].getsockname()[1]
        try:
            async with connect(f"ws://127.0.0.1:{port}") as a, connect(f"ws://127.0.0.1:{port}") as b:
                await send(a, type="auth_bind", access_token=token)
                assert await recv(a) == {"type": "auth_bound", "ok": True}
                await send(a, type="create")
                room_reply = await recv(a)
                code = room_reply["code"]
                await send(b, type="join", code=code)
                assert (await recv(b))["status"] == "joined"
                assert (await recv(a))["type"] == "started"
                assert (await recv(b))["type"] == "started"
                room = room_server.rooms[code]
                correct_alias = room.cards[0]["aliases"][0]
                await send(a, type="guess", guess=correct_alias)
                assert (await recv(a))["type"] == "guess"
                assert (await recv(b))["type"] == "guess"
                finished_a, finished_b = await recv(a), await recv(b)
                assert finished_a["type"] == "finished"
                assert finished_b["type"] == "finished"
                assert finished_a["winner"] == finished_b["winner"] == 0
                await send(a, type="guess", guess=correct_alias)
                assert (await recv(a))["type"] == "error"
                return code
        finally:
            listener.close()
            await listener.wait_closed()
            room_server.rooms.clear()
            room_server.connections.clear()
            room_server.waiting.clear()
            room_server.verified_accounts.clear()

    asyncio.run(run_match())
    profile = api.get("/api/me", headers={"Authorization": "Bearer " + token})
    assert profile.status_code == 200
    assert profile.json()["user"]["points"] == 10
