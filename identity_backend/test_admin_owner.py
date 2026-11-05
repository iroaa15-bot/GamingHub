import io
import os
import secrets

import psycopg
from fastapi.testclient import TestClient
from PIL import Image

from identity_backend.app import app, initialize


def test_owner_setup_secure_login_and_real_content_lifecycle(monkeypatch):
    # This test mutates dedicated test-only admin tables, never a deployed database.
    assert "gaminghub_identity_ci" in os.environ["GAMINGHUB_DATABASE_URL"]
    initialize()
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        db.execute("TRUNCATE admin_browser_sessions,admin_owners,admin_login_failures CASCADE")
    token = secrets.token_urlsafe(40)
    monkeypatch.setenv("GAMINGHUB_ADMIN_SETUP_TOKEN", token)
    monkeypatch.setenv("GAMINGHUB_ADMIN_OWNER_EMAIL", "owner@example.test")
    client = TestClient(app, base_url="https://testserver")
    headers = {"Origin": "https://testserver", "X-GamingHub-Admin": "1"}
    setup = {"email": "owner@example.test", "password": "test-only-owner-password", "setup_token": token}
    assert client.get("/api/admin/content").status_code == 403
    assert client.post("/api/admin/auth/setup", json=setup).status_code == 403
    assert client.post("/api/admin/auth/setup", json={**setup, "email": "attacker@example.test"}, headers=headers).status_code == 403
    created = client.post("/api/admin/auth/setup", json=setup, headers=headers)
    assert created.status_code == 200, created.text
    cookie = created.headers["set-cookie"].lower()
    assert "httponly" in cookie and "secure" in cookie and "samesite=strict" in cookie
    assert "password" not in created.json() and "token" not in created.json()
    assert client.post("/api/admin/auth/setup", json=setup, headers=headers).status_code == 409
    assert client.get("/api/admin/auth/me").json()["email"] == setup["email"]
    assert client.post("/api/admin/content", json={"category": "question", "title": "CSRF", "payload": {}}).status_code == 403
    assert client.post("/api/admin/content", json={"category": "question", "title": "CSRF", "payload": {}}, headers={**headers, "Origin": "https://evil.example"}).status_code == 403
    # A player bearer token cannot confer admin access.
    outsider = TestClient(app, base_url="https://testserver")
    guest = outsider.post("/api/auth/guest").json()
    assert outsider.get("/api/admin/content", headers={"Authorization": "Bearer " + guest["access_token"]}).status_code == 403
    payload = {"game_id": "3", "level": 1, "topic": "science", "ar": "كم عدد أيام الأسبوع؟", "en": "How many days are in a week?", "choices_ar": ["سبعة", "ثمانية", "ستة", "خمسة"], "choices_en": ["Seven", "Eight", "Six", "Five"], "correct": 0}
    draft = client.post("/api/admin/content", json={"category": "question", "title": "Owner question", "payload": payload}, headers=headers)
    assert draft.status_code == 201, draft.text
    did = draft.json()["id"]
    route = "/api/admin/content/" + did
    assert client.post(route + "/validate", headers=headers).status_code == 200
    for action in ("submit", "approve"):
        assert client.post(route + "/review/" + action, headers=headers).status_code == 200
    result = client.post(route + "/publish", headers=headers)
    assert result.status_code == 201, result.text
    pid = result.json()["id"]
    assert client.post(route + "/publish", headers=headers).json()["id"] == pid
    assert any(q["id"] == "pub_" + pid for q in client.get("/api/content/gameplay").json()["items"])
    image = io.BytesIO(); Image.new("RGB", (8, 8), "blue").save(image, format="PNG")
    uploaded = client.post("/api/admin/assets", content=image.getvalue(), headers={**headers, "Content-Type": "application/octet-stream"})
    assert uploaded.status_code == 201, uploaded.text
    aid = uploaded.json()["id"]
    backup = client.get("/api/admin/backup")
    assert backup.status_code == 200
    assert any(a["id"] == aid and a["data_base64"] for a in backup.json()["assets"])
    assert "password_hash" not in backup.text and "admin_browser_sessions" not in backup.text
    assert client.post("/api/admin/published/" + pid + "/revoke", headers=headers).status_code == 200
    assert not any(q["id"] == "pub_" + pid for q in client.get("/api/content/gameplay").json()["items"])
    assert any(q["id"] == pid and not q["active"] for q in client.get("/api/admin/published").json()["items"])
    assert client.post("/api/admin/auth/logout", headers=headers).status_code == 200
    assert client.get("/api/admin/auth/me").status_code == 401
    credentials = {k: setup[k] for k in ("email", "password")}
    assert client.post("/api/admin/auth/login", json={**credentials, "password": "wrong-password-12"}, headers=headers).status_code == 401
    assert client.post("/api/admin/auth/login", json=credentials, headers=headers).status_code == 200
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        stored = db.execute("SELECT password_hash FROM admin_owners WHERE email=%s", (setup["email"],)).fetchone()[0]
        assert stored != setup["password"]
        db.execute("TRUNCATE admin_browser_sessions,admin_owners,admin_login_failures CASCADE")
