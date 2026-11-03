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

def test_award_points_idempotency(monkeypatch):
    initialize()
    monkeypatch.setenv("GAMINGHUB_INTERNAL_ADMIN_KEY","ci-secret")
    client = TestClient(app)
    token = client.post("/api/auth/guest").json()["access_token"]
    headers = {"Authorization": "Bearer " + token}
    data = {"match_id": "ci-match-unique-001", "points": 10}
    assert client.post("/api/admin/award-points", json=data, headers=headers).status_code == 403
    headers["X-Admin-Key"] = "ci-secret"
    first = client.post("/api/admin/award-points", json=data, headers=headers)
    assert first.status_code == 200, first.text
    assert first.json()["points"] == 10
    second = client.post("/api/admin/award-points", json=data, headers=headers)
    assert second.status_code == 200, second.text
    assert second.json()["points"] == 10
    assert second.json()["awarded"] is False
