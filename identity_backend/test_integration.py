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

def test_award_persists_after_new_login(monkeypatch):
    initialize()
    monkeypatch.setenv("GAMINGHUB_INTERNAL_ADMIN_KEY","ci-key")
    client=TestClient(app)
    email="persistent@example.test"
    password="persistent-password-123"
    register=client.post("/api/auth/register",json={"email":email,"password":password,"display_name":"Persistent"})
    assert register.status_code==201,register.text
    token=register.json()["access_token"]
    headers={"Authorization":"Bearer "+token,"X-Admin-Key":"ci-key"}
    award=client.post("/api/admin/award-points",json={"match_id":"persistent-match-001","points":15},headers=headers)
    assert award.status_code==200,award.text
    assert award.json()["points"]==15
    assert client.post("/api/auth/logout",headers=headers).status_code==200
    login=client.post("/api/auth/login",json={"email":email,"password":password})
    assert login.status_code==200,login.text
    fresh={"Authorization":"Bearer "+login.json()["access_token"]}
    assert client.get("/api/me",headers=fresh).json()["user"]["points"]==15

def test_conflicting_duplicate_award_is_not_counted(monkeypatch):
    initialize()
    monkeypatch.setenv("GAMINGHUB_INTERNAL_ADMIN_KEY","ci-key")
    client=TestClient(app)
    guest=client.post("/api/auth/guest")
    assert guest.status_code==201
    headers={"Authorization":"Bearer "+guest.json()["access_token"],"X-Admin-Key":"ci-key"}
    match="conflicting-match-001"
    first=client.post("/api/admin/award-points",json={"match_id":match,"points":5},headers=headers)
    assert first.status_code==200,first.text
    second=client.post("/api/admin/award-points",json={"match_id":match,"points":100},headers=headers)
    assert second.status_code==200,second.text
    assert second.json()=={"awarded":False,"points":5}
    assert client.get("/api/me",headers=headers).json()["user"]["points"]==5


def test_admin_content_drafts_crud_and_authorization(monkeypatch):
    monkeypatch.setenv("GAMINGHUB_INTERNAL_ADMIN_KEY", "ci-admin-secret")
    client = TestClient(app)
    draft = {"category": "question", "title": "Animal quiz", "payload": {"answer": "duck"}}
    assert client.post("/api/admin/content", json=draft).status_code == 403
    headers = {"X-Admin-Key": "ci-admin-secret"}
    created = client.post("/api/admin/content", json=draft, headers=headers)
    assert created.status_code == 201, created.text
    draft_id = created.json()["id"]
    listed = client.get("/api/admin/content", headers=headers)
    assert listed.status_code == 200, listed.text
    assert any(item["id"] == draft_id for item in listed.json()["drafts"])
    edited = dict(draft, title="Updated quiz")
    assert client.put(f"/api/admin/content/{draft_id}", json=edited, headers=headers).status_code == 200
    assert client.delete(f"/api/admin/content/{draft_id}", headers=headers).status_code == 200
    assert client.delete(f"/api/admin/content/{draft_id}", headers=headers).status_code == 404
    assert client.post("/api/admin/content", json={"category": "invalid", "title": "Bad"} , headers=headers).status_code == 422


def test_admin_dashboard_is_served_as_html():
    client = TestClient(app)
    response = client.get("/admin/dashboard")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "Gaming Hub" in response.text
    assert "admin" in response.text.lower()


def test_admin_binary_upload_download_and_rejections(monkeypatch):
    import hashlib
    monkeypatch.setenv("GAMINGHUB_INTERNAL_ADMIN_KEY", "ci-assets-key")
    client = TestClient(app)
    png = bytes.fromhex("89504e470d0a1a0a") + b"staged-fixture"
    headers = {"X-Admin-Key": "ci-assets-key", "Content-Type": "application/octet-stream"}
    assert client.post("/api/admin/assets", data=png).status_code == 403
    uploaded = client.post("/api/admin/assets", content=png, headers=headers)
    assert uploaded.status_code == 201, uploaded.text
    asset_id = uploaded.json()["id"]
    assert uploaded.json()["sha256"] == hashlib.sha256(png).hexdigest()
    assert uploaded.json()["status"] == "staged"
    assert client.get(f"/api/admin/assets/{asset_id}").status_code == 403
    downloaded = client.get(f"/api/admin/assets/{asset_id}", headers=headers)
    assert downloaded.status_code == 200
    assert downloaded.content == png
    assert client.post("/api/admin/assets", content=b"not a media file", headers=headers).status_code == 415
    assert client.post("/api/admin/assets", content=png + b"x" * (8 * 1024 * 1024), headers=headers).status_code == 413
    assert client.delete(f"/api/admin/assets/{asset_id}", headers=headers).status_code == 200
    assert client.get(f"/api/admin/assets/{asset_id}", headers=headers).status_code == 404


def test_draft_rejects_missing_or_mismatched_staged_asset(monkeypatch):
    monkeypatch.setenv("GAMINGHUB_INTERNAL_ADMIN_KEY", "ci-asset-reference")
    client = TestClient(app)
    headers = {"X-Admin-Key": "ci-asset-reference"}
    import uuid
    missing = {"category": "image", "title": "Missing", "payload": {"staged_asset_id": str(uuid.uuid4())}}
    assert client.post("/api/admin/content", json=missing, headers=headers).status_code == 422
    wav = b"RIFF" + bytes(4) + b"WAVE" + b"audio-fixture"
    uploaded = client.post("/api/admin/assets", content=wav, headers={**headers, "Content-Type": "application/octet-stream"})
    assert uploaded.status_code == 201, uploaded.text
    asset_id = uploaded.json()["id"]
    mismatch = {"category": "image", "title": "Wrong type", "payload": {"staged_asset_id": asset_id}}
    assert client.post("/api/admin/content", json=mismatch, headers=headers).status_code == 422
    valid = {"category": "sound", "title": "Correct type", "payload": {"staged_asset_id": asset_id}}
    created = client.post("/api/admin/content", json=valid, headers=headers)
    assert created.status_code == 201, created.text
    assert client.delete(f"/api/admin/assets/{asset_id}", headers=headers).status_code == 409
    assert client.delete(f"/api/admin/content/{created.json()['id']}", headers=headers).status_code == 200
    assert client.delete(f"/api/admin/assets/{asset_id}", headers=headers).status_code == 200


def test_content_review_transitions_are_enforced(monkeypatch):
    monkeypatch.setenv("GAMINGHUB_INTERNAL_ADMIN_KEY", "ci-review-secret")
    client = TestClient(app)
    headers = {"X-Admin-Key": "ci-review-secret"}
    draft = client.post("/api/admin/content", json={"category": "question", "title": "Review example", "payload": {}}, headers=headers)
    assert draft.status_code == 201, draft.text
    draft_id = draft.json()["id"]
    url = f"/api/admin/content/{draft_id}/review/"
    assert client.post(url + "approve", headers=headers).status_code == 409
    assert client.post(url + "submit").status_code == 403
    assert client.post(url + "submit", headers=headers).json()["review_status"] == "in_review"
    assert client.post(url + "approve", headers=headers).json()["review_status"] == "approved"
    assert client.post(url + "approve", headers=headers).status_code == 409
    assert client.delete(f"/api/admin/content/{draft_id}", headers=headers).status_code == 200


def test_approved_draft_edit_resets_review_status(monkeypatch):
    monkeypatch.setenv("GAMINGHUB_INTERNAL_ADMIN_KEY", "ci-edit-review")
    client = TestClient(app)
    headers = {"X-Admin-Key": "ci-edit-review"}
    draft = {"category": "question", "title": "Initial", "payload": {"answer": "duck"}}
    created = client.post("/api/admin/content", json=draft, headers=headers)
    assert created.status_code == 201, created.text
    draft_id = created.json()["id"]
    for action in ("submit", "approve"):
        response = client.post(f"/api/admin/content/{draft_id}/review/{action}", headers=headers)
        assert response.status_code == 200, response.text
    updated = client.put(f"/api/admin/content/{draft_id}", json={**draft, "title": "Changed"}, headers=headers)
    assert updated.status_code == 200, updated.text
    listed = client.get("/api/admin/content", headers=headers)
    row = next(d for d in listed.json()["drafts"] if d["id"] == draft_id)
    assert row["review_status"] == "draft"
    assert client.post(f"/api/admin/content/{draft_id}/review/approve", headers=headers).status_code == 409
    assert client.delete(f"/api/admin/content/{draft_id}", headers=headers).status_code == 200
