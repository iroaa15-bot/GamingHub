import os
from fastapi.testclient import TestClient
from identity_backend.app import app, initialize
import psycopg

def test_account_lifecycle():
    initialize()
    client = TestClient(app)
    assert client.get("/api/ready").status_code == 200
    reg = client.post("/api/auth/register",json={"email":"test@example.test","password":"test-password-123","display_name":"Tester"})
    assert reg.status_code == 201,reg.text
    token=reg.json()["access_token"]
    headers={"Authorization":"Bearer "+token}
    assert client.get("/api/me",headers=headers).json()["user"]["email"]=="test@example.test"
    assert client.post("/api/auth/login",json={"email":"test@example.test","password":"test-password-123"}).status_code==200
    guest=client.post("/api/auth/guest")
    assert guest.status_code==201
    ghead={"Authorization":"Bearer "+guest.json()["access_token"]}
    assert client.post("/api/auth/upgrade",json={"email":"guest@example.test","password":"guest-password-123","display_name":"Guest Upgraded"},headers=ghead).status_code==200
    assert client.post("/api/auth/logout",headers=headers).status_code==200
    assert client.get("/api/me",headers=headers).status_code==401
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        assert db.execute("SELECT count(*) FROM identity_users WHERE email=%s",("test@example.test",)).fetchone()[0]==1
