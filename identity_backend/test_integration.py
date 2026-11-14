import os
from fastapi.testclient import TestClient
from identity_backend.app import app, initialize
import psycopg

def test_local_progress_backup_merges_without_modifying_ranked_points():
    initialize()
    client=TestClient(app)
    session=client.post('/api/auth/guest').json()
    headers={'Authorization':'Bearer '+session['access_token']}
    uid=client.get('/api/me',headers=headers).json()['user']['id']
    with psycopg.connect(os.environ['GAMINGHUB_DATABASE_URL']) as db:
        db.execute('UPDATE identity_users SET points=37 WHERE id=%s',(uid,))
    assert client.post('/api/me/progress',json={'progress':{'xp':25,'wins':1}},headers=headers).status_code==200
    result=client.post('/api/me/progress',json={'progress':{'xp':20,'matches':2}},headers=headers)
    user=result.json()['user']
    assert user['local_progress']=={'xp':25,'wins':1,'matches':2,'picture_wins':0}
    assert user['points']==37 and user['id']==uid
    for body in ({'progress':{'points':999}}, {'progress':{'xp':True}},
                 {'progress':{'xp':-1}}, {'progress':{'xp':1},'user_id':'other'}):
        assert client.post('/api/me/progress',json=body,headers=headers).status_code==422
    assert client.post('/api/me/progress',json={'progress':{'xp':1}}).status_code==401
    other=client.post('/api/auth/guest').json()
    other_user=client.get('/api/me',headers={'Authorization':'Bearer '+other['access_token']}).json()['user']
    assert other_user['local_progress']=={} and other_user['points']==0

def test_refresh_rotation_expiry_logout_and_replay():
    initialize()
    client=TestClient(app)
    session=client.post('/api/auth/guest').json()
    headers={'Authorization':'Bearer '+session['access_token']}
    uid=client.get('/api/me',headers=headers).json()['user']['id']
    with psycopg.connect(os.environ['GAMINGHUB_DATABASE_URL']) as db:
        db.execute("UPDATE identity_sessions SET expires_at=CURRENT_TIMESTAMP-INTERVAL '1 second' WHERE user_id=%s",(uid,))
    assert client.get('/api/me',headers=headers).status_code==401
    restored=client.post('/api/auth/refresh',json={'refresh_token':session['refresh_token']})
    assert restored.status_code==200
    fresh=restored.json()
    assert fresh['refresh_token']!=session['refresh_token']
    headers={'Authorization':'Bearer '+fresh['access_token']}
    assert client.get('/api/me',headers=headers).json()['user']['id']==uid
    assert client.post('/api/auth/refresh',json={'refresh_token':session['refresh_token']}).status_code==401
    assert client.get('/api/me',headers=headers).status_code==401
    assert client.post('/api/auth/refresh',json={'refresh_token':fresh['refresh_token']}).status_code==401
    session=client.post('/api/auth/guest').json()
    assert client.post('/api/auth/logout',headers={'Authorization':'Bearer '+session['access_token']}).status_code==200
    assert client.post('/api/auth/refresh',json={'refresh_token':session['refresh_token']}).status_code==401

def test_social_guest_link_preserves_id_points_and_requires_proof(monkeypatch):
    import uuid
    from identity_backend import provider_tokens
    initialize()
    monkeypatch.setenv('GAMINGHUB_GOOGLE_WEB_CLIENT_ID','unit-test-client')
    subject=str(uuid.uuid4())
    # This exercises the DB/link boundary. It is not a real Google sign-in test.
    monkeypatch.setattr(provider_tokens,'google_identity',lambda token,nonce:
        provider_tokens.ProviderIdentity(subject,'Linked player',subject+'@example.test'))
    client=TestClient(app)
    session=client.post('/api/auth/guest').json()
    headers={'Authorization':'Bearer '+session['access_token']}
    uid=client.get('/api/me',headers=headers).json()['user']['id']
    with psycopg.connect(os.environ['GAMINGHUB_DATABASE_URL']) as db:
        db.execute('UPDATE identity_users SET points=37 WHERE id=%s',(uid,))
    nonce=client.post('/api/auth/challenge',json={'provider':'google'},headers=headers).json()['nonce']
    payload={'provider':'google','nonce':nonce,'token':'unit-token-not-from-google'}
    assert client.post('/api/auth/social',json=payload).status_code==401
    linked=client.post('/api/auth/social',json=payload,headers=headers)
    assert linked.status_code==200,linked.text
    user=client.get('/api/me',headers={'Authorization':'Bearer '+linked.json()['access_token']}).json()['user']
    assert user['id']==uid and user['points']==37 and not user['is_guest']
    assert client.post('/api/auth/social',json=payload,headers=headers).status_code==401
    nonce=client.post('/api/auth/challenge',json={'provider':'google'}).json()['nonce']
    returned=client.post('/api/auth/social',json={**payload,'nonce':nonce})
    assert returned.status_code==200
    assert client.get('/api/me',headers={'Authorization':'Bearer '+returned.json()['access_token']}).json()['user']['id']==uid

def test_social_accounts_with_same_email_stay_independent(monkeypatch):
    import uuid
    from identity_backend import provider_tokens
    initialize()
    marker=str(uuid.uuid4())
    monkeypatch.setenv('GAMINGHUB_GOOGLE_WEB_CLIENT_ID','test-client')
    monkeypatch.setenv('GAMINGHUB_FACEBOOK_APP_ID','test-app')
    monkeypatch.setenv('GAMINGHUB_FACEBOOK_APP_SECRET','test-secret')
    monkeypatch.setenv('GAMINGHUB_META_GRAPH_VERSION','v22.0')
    for provider in ['google','facebook']:
        monkeypatch.setattr(provider_tokens,provider+'_identity',lambda *args:
            provider_tokens.ProviderIdentity(marker,'Independent',marker+'@example.test'))
    client=TestClient(app)
    def sign_in(provider,headers):
        nonce=client.post('/api/auth/challenge',json={'provider':provider},headers=headers).json()['nonce']
        result=client.post('/api/auth/social',json={'provider':provider,'nonce':nonce,'token':'fake-provider-token-for-db-test'},headers=headers)
        assert result.status_code==200,result.text
        header={'Authorization':'Bearer '+result.json()['access_token']}
        return header,client.get('/api/me',headers=header).json()['user']
    first_header,first=sign_in('google',{})
    with psycopg.connect(os.environ['GAMINGHUB_DATABASE_URL']) as db:
        db.execute('UPDATE identity_users SET points=37 WHERE id=%s',(first['id'],))
    second_header,second=sign_in('facebook',first_header)
    assert second['id']!=first['id'] and second['points']==0
    assert second['providers']==['facebook']
    _,again=sign_in('google',second_header)
    assert again['id']==first['id'] and again['points']==37
    assert again['providers']==['google']

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


def test_approved_content_publish_snapshot_and_revoke(monkeypatch):
    monkeypatch.setenv("GAMINGHUB_INTERNAL_ADMIN_KEY", "ci-publish-secret")
    client = TestClient(app)
    headers = {"X-Admin-Key": "ci-publish-secret"}
    original = {"category": "question", "title": "Published question", "payload": {"answer": "duck"}}
    draft = client.post("/api/admin/content", json=original, headers=headers)
    assert draft.status_code == 201, draft.text
    draft_id = draft.json()["id"]
    publish_url = f"/api/admin/content/{draft_id}/publish"
    assert client.post(publish_url).status_code == 403
    assert client.post(publish_url, headers=headers).status_code == 409
    for action in ("submit", "approve"):
        assert client.post(f"/api/admin/content/{draft_id}/review/{action}", headers=headers).status_code == 200
    published = client.post(publish_url, headers=headers)
    assert published.status_code == 201, published.text
    item_id = published.json()["id"]
    visible = client.get("/api/content?category=question")
    assert visible.status_code == 200
    assert any(item["id"] == item_id and item["payload"]["answer"] == "duck" for item in visible.json()["items"])
    modified = {"category": "question", "title": "Edited question", "payload": {"answer": "goose"}}
    assert client.put(f"/api/admin/content/{draft_id}", json=modified, headers=headers).status_code == 200
    assert client.post(publish_url, headers=headers).status_code == 409
    visible = client.get("/api/content?category=question")
    assert any(item["id"] == item_id and item["payload"]["answer"] == "duck" for item in visible.json()["items"])
    assert client.post(f"/api/admin/published/{item_id}/revoke").status_code == 403
    assert client.post(f"/api/admin/published/{item_id}/revoke", headers=headers).status_code == 200
    assert not any(item["id"] == item_id for item in client.get("/api/content?category=question").json()["items"])
    assert client.delete(f"/api/admin/content/{draft_id}", headers=headers).status_code == 200
