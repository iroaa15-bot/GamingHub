"""Disabled until provider configuration exists; never merges accounts by email alone."""
import hashlib
import os
import secrets
import uuid
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field
from identity_backend import provider_tokens

router = APIRouter(prefix="/api/auth")

@router.get("/providers")
def providers():
    return {"google":configured("google"),"facebook":configured("facebook"),
        "facebook_app_id":os.environ.get("GAMINGHUB_FACEBOOK_APP_ID","")}

def initialize_social(db):
    db.execute("ALTER TABLE identity_users ADD COLUMN IF NOT EXISTS avatar_url TEXT NOT NULL DEFAULT ''")
    db.execute("""CREATE TABLE IF NOT EXISTS identity_providers (
        provider TEXT NOT NULL, subject TEXT NOT NULL,
        user_id TEXT NOT NULL REFERENCES identity_users(id), PRIMARY KEY(provider,subject),
        UNIQUE(provider,user_id))""")
    db.execute("""CREATE TABLE IF NOT EXISTS identity_challenges (
        digest TEXT PRIMARY KEY, provider TEXT NOT NULL, user_id TEXT,
        expires_at TIMESTAMPTZ NOT NULL, consumed BOOLEAN NOT NULL DEFAULT FALSE)""")

def configured(provider):
    if provider == "google": return bool(os.environ.get("GAMINGHUB_GOOGLE_WEB_CLIENT_ID"))
    if provider == "facebook": return all(os.environ.get(k) for k in (
        "GAMINGHUB_FACEBOOK_APP_ID","GAMINGHUB_FACEBOOK_APP_SECRET","GAMINGHUB_META_GRAPH_VERSION"))
    return False

class Challenge(BaseModel):
    provider: str = Field(pattern="^(google|facebook)$")

@router.post("/challenge")
def challenge(body: Challenge, authorization: str = Header(default="")):
    from identity_backend.app import database, get_identity
    if not configured(body.provider): raise HTTPException(503,"Provider configuration required")
    identity = get_identity(authorization) if authorization else None
    nonce = secrets.token_urlsafe(32)
    with database() as db:
        db.execute("DELETE FROM identity_challenges WHERE expires_at<CURRENT_TIMESTAMP")
        db.execute("""INSERT INTO identity_challenges(digest,provider,user_id,expires_at)
            VALUES(%s,%s,%s,CURRENT_TIMESTAMP+INTERVAL '5 minutes')""",
            (hashlib.sha256(nonce.encode()).hexdigest(),body.provider,identity["id"] if identity else None))
        db.commit()
    return {"nonce":nonce,"google_web_client_id":os.environ.get("GAMINGHUB_GOOGLE_WEB_CLIENT_ID","") if body.provider=="google" else ""}

class SocialCredentials(Challenge):
    token: str = Field(min_length=16,max_length=16384)
    nonce: str = Field(min_length=32,max_length=128)

@router.post("/social")
def social(body: SocialCredentials, authorization: str = Header(default="")):
    from identity_backend.app import database, get_identity, issue_session
    if not configured(body.provider): raise HTTPException(503,"Provider configuration required")
    current = get_identity(authorization) if authorization else None
    digest = hashlib.sha256(body.nonce.encode()).hexdigest()
    with database() as db:
        entry = db.execute("""SELECT provider,user_id FROM identity_challenges
            WHERE digest=%s AND NOT consumed AND expires_at>CURRENT_TIMESTAMP FOR UPDATE""",(digest,)).fetchone()
        if not entry or entry != (body.provider,current["id"] if current else None):
            raise HTTPException(401,"Invalid sign-in challenge")
        verified = (provider_tokens.google_identity(body.token,body.nonce) if body.provider=="google"
            else provider_tokens.facebook_identity(body.token))
        # Serialize provider-subject creation; the unique constraints remain the final guard.
        db.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))",(body.provider+":"+verified.subject,))
        linked = db.execute("SELECT user_id FROM identity_providers WHERE provider=%s AND subject=%s",
            (body.provider,verified.subject)).fetchone()
        if linked and current and linked[0] != current["id"]:
            raise HTTPException(409,"Provider belongs to another account; progress was preserved")
        if linked:
            uid = linked[0]
        else:
            # A matching email is not sufficient proof to link an existing account.
            if verified.email and db.execute("SELECT id FROM identity_users WHERE email=%s AND id<>%s",
                (verified.email,current["id"] if current else "")).fetchone():
                raise HTTPException(409,"Sign in to the existing account before linking this provider")
            uid = current["id"] if current else str(uuid.uuid4())
            if not current:
                db.execute("INSERT INTO identity_users(id,email,display_name,avatar_url) VALUES(%s,%s,%s,%s)",
                    (uid,verified.email,verified.name,verified.avatar))
            else:
                if db.execute("SELECT 1 FROM identity_providers WHERE provider=%s AND user_id=%s",(body.provider,uid)).fetchone():
                    raise HTTPException(409,"A different provider identity is already linked")
                db.execute("""UPDATE identity_users SET is_guest=FALSE,display_name=%s,avatar_url=CASE WHEN avatar_url LIKE '/api/avatars/%%' THEN avatar_url ELSE %s END,
                    email=COALESCE(email,%s) WHERE id=%s""",(verified.name,verified.avatar,verified.email,uid))
            db.execute("INSERT INTO identity_providers(provider,subject,user_id) VALUES(%s,%s,%s)",(body.provider,verified.subject,uid))
        db.execute("UPDATE identity_challenges SET consumed=TRUE WHERE digest=%s",(digest,))
        result = issue_session(db,uid)
        db.commit()
    return result
