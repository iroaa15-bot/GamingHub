"""Real PostgreSQL regression for historical linked accounts; tokens are fixtures."""
import os
import uuid
import pytest
import psycopg
from fastapi.testclient import TestClient
from identity_backend.app import app, initialize, issue_session
from identity_backend import provider_tokens


@pytest.mark.parametrize("first", ["google", "facebook", "concurrent"])
@pytest.mark.parametrize("password_account", [False, True])
def test_historical_links_separate_once_without_duplicating_progress(monkeypatch, first, password_account):
    initialize()
    uid, subject = str(uuid.uuid4()), str(uuid.uuid4())
    monkeypatch.setenv("GAMINGHUB_GOOGLE_WEB_CLIENT_ID", "test-client")
    monkeypatch.setenv("GAMINGHUB_FACEBOOK_APP_ID", "test-app")
    monkeypatch.setenv("GAMINGHUB_FACEBOOK_APP_SECRET", "test-secret")
    monkeypatch.setenv("GAMINGHUB_META_GRAPH_VERSION", "v22.0")
    for provider in ("google", "facebook"):
        monkeypatch.setattr(provider_tokens, provider + "_identity", lambda *args:
            provider_tokens.ProviderIdentity(subject, "Verified player", subject + "@example.test", "https://example.test/avatar.jpg"))
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        db.execute("""INSERT INTO identity_users(id,display_name,password_hash,points,local_progress,avatar_url)
            VALUES(%s,'Original player',%s,37,'{"xp":875,"wins":8}'::jsonb,'/api/avatars/original/photo.jpg')""",
            (uid, "existing-password-hash" if password_account else None))
        for provider in ("google", "facebook"):
            db.execute("INSERT INTO identity_providers VALUES(%s,%s,%s)", (provider, subject, uid))
        old = issue_session(db, uid)
    client = TestClient(app)
    def login(provider):
        nonce = client.post("/api/auth/challenge", json={"provider": provider}).json()["nonce"]
        result = client.post("/api/auth/social", json={"provider": provider, "nonce": nonce,
                                                     "token": "fixture-token-not-from-provider"})
        assert result.status_code == 200, result.text
        headers = {"Authorization": "Bearer " + result.json()["access_token"]}
        return client.get("/api/me", headers=headers).json()["user"]
    if first == "concurrent":
        from concurrent.futures import ThreadPoolExecutor
        with ThreadPoolExecutor(max_workers=2) as executor:
            users = dict(zip(("google", "facebook"), executor.map(login, ("google", "facebook"))))
    else:
        users = {first: login(first)}
        other = "facebook" if first == "google" else "google"
        users[other] = login(other)
    assert users["google"]["id"] != users["facebook"]["id"]
    for provider, user in users.items():
        assert user["providers"] == [provider]
        keeps_progress = provider == "google" and not password_account
        assert user["points"] == (37 if keeps_progress else 0)
        assert user["local_progress"] == ({"xp": 875, "wins": 8} if keeps_progress else {})
        assert user["avatar_url"] == ("/api/avatars/original/photo.jpg" if keeps_progress else "https://example.test/avatar.jpg")
        again = login(provider)
        assert again["id"] == user["id"] and again["points"] == user["points"]
    assert client.get("/api/me", headers={"Authorization": "Bearer " + old["access_token"]}).status_code == 401
    assert client.post("/api/auth/refresh", json={"refresh_token": old["refresh_token"]}).status_code == 401
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        assert db.execute("SELECT points,local_progress FROM identity_users WHERE id=%s", (uid,)).fetchone() == (37, {"xp": 875, "wins": 8})
        ids = list({uid, users["google"]["id"], users["facebook"]["id"]})
        assert db.execute("SELECT sum(points) FROM identity_users WHERE id=ANY(%s)", (ids,)).fetchone()[0] == 37
