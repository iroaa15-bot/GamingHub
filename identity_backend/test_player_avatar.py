import base64
import io
import uuid
from PIL import Image
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from identity_backend.app import app,initialize
from identity_backend.player_avatar import normalize_avatar

def encoded(color="red"):
    output=io.BytesIO();Image.new("RGB",(80,40),color).save(output,"PNG")
    return base64.b64encode(output.getvalue()).decode()

def test_avatar_normalization_rejects_invalid_input_and_removes_metadata():
    result=normalize_avatar(encoded())
    with Image.open(io.BytesIO(result)) as image:
        assert image.format=="JPEG" and image.size==(256,256)
        assert not image.getexif()
    for value in ("not base64!",base64.b64encode(b"<svg></svg>").decode(),"a"*1000001):
        with pytest.raises(HTTPException):normalize_avatar(value)

def test_avatar_is_account_owned_persistent_and_cannot_change_points():
    initialize();client=TestClient(app)
    session=client.post("/api/auth/guest").json();headers={"Authorization":"Bearer "+session["access_token"]}
    before=client.get("/api/me",headers=headers).json()["user"]
    assert client.post("/api/me/avatar",json={"image_base64":encoded()}).status_code==401
    assert client.post("/api/me/avatar",headers=headers,json={"image_base64":encoded(),"user_id":"other"}).status_code==422
    saved=client.post("/api/me/avatar",headers=headers,json={"image_base64":encoded()})
    assert saved.status_code==200
    url=saved.json()["user"]["avatar_url"]
    assert url.startswith("/api/avatars/"+before["id"]+"/")
    assert client.get(url).headers["content-type"]=="image/jpeg"
    assert client.get("/api/me",headers=headers).json()["user"]["points"]==before["points"]
    email=str(uuid.uuid4())+"@example.test"
    credentials={"email":email,"password":"test-avatar-password-123","display_name":"Avatar test"}
    upgraded=client.post("/api/auth/upgrade",headers=headers,json=credentials)
    assert upgraded.status_code==200
    second=client.post("/api/auth/login",json=credentials).json()
    restored=client.get("/api/me",headers={"Authorization":"Bearer "+second["access_token"]}).json()["user"]
    assert restored["id"]==before["id"] and restored["avatar_url"]==url
    from identity_backend.session_bindings import verify_session
    import os
    bound=verify_session(os.environ["GAMINGHUB_DATABASE_URL"],second["access_token"])
    assert bound.user_id==before["id"] and bound.avatar_url==url and bound.display_name=="Avatar test"
    other=client.post("/api/auth/guest").json()
    assert client.get("/api/me",headers={"Authorization":"Bearer "+other["access_token"]}).json()["user"]["avatar_url"]==""
    replaced=client.post("/api/me/avatar",headers={"Authorization":"Bearer "+second["access_token"]},json={"image_base64":encoded("blue")})
    assert replaced.status_code==200 and replaced.json()["user"]["avatar_url"]!=url
    assert client.get(url).status_code==404

def test_room_profiles_come_only_from_verified_accounts(monkeypatch):
    import asyncio
    import os
    import sys
    import time
    from pathlib import Path
    from types import SimpleNamespace
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"server"))
    from account_rooms import AccountRooms
    initialize();client=TestClient(app)
    session=client.post("/api/auth/guest").json()
    headers={"Authorization":"Bearer "+session["access_token"]}
    image=client.post("/api/me/avatar",headers=headers,json={"image_base64":encoded()}).json()["user"]["avatar_url"]
    class Base:
        async def send(self,ws,message):self.messages.append(message)
    class Hub(AccountRooms,Base):pass
    hub=Hub();socket=object();hub.identities={socket:{"exp":time.time()+60}};hub.messages=[]
    hub.rooms={"123456":SimpleNamespace(peers=[socket,object()])}
    async def exercise():
        await hub.bind_account(socket,{"protocol":3,"access_token":session["access_token"],"display_name":"Forged","avatar_url":"https://untrusted.invalid"})
        await hub.send(socket,{"type":"duel_state","code":"123456"})
    asyncio.run(exercise())
    public=hub.messages[-1]["profiles"]
    assert public==[{"display_name":"Guest","avatar_url":image},{}]
    assert "email" not in public[0] and "user_id" not in public[0]
