"""Gaming Hub isolated identity API proof of integration (not production deployment)."""
import hashlib
import os
import secrets
import uuid
from contextlib import contextmanager

import psycopg
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="Gaming Hub Identity Integration")
from identity_backend.gameplay_content import router as gameplay_router
app.include_router(gameplay_router)
from identity_backend.admin_content import router as admin_content_router
app.include_router(admin_content_router)
from identity_backend.admin_assets import router as admin_assets_router
app.include_router(admin_assets_router)
from identity_backend.published_content import router as published_content_router
app.include_router(published_content_router)
DATABASE_URL = os.environ.get("GAMINGHUB_DATABASE_URL", "")
if not DATABASE_URL:
    raise RuntimeError("GAMINGHUB_DATABASE_URL is required")

@contextmanager
def database():
    with psycopg.connect(DATABASE_URL) as db:
        yield db

def initialize():
    with database() as db:
        db.execute("""CREATE TABLE IF NOT EXISTS identity_users (
            id TEXT PRIMARY KEY, email TEXT UNIQUE, display_name TEXT NOT NULL,
            password_hash TEXT, salt TEXT, is_guest BOOLEAN NOT NULL DEFAULT FALSE,
            points INTEGER NOT NULL DEFAULT 0)""")
        db.execute("""CREATE TABLE IF NOT EXISTS identity_sessions (
            token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES identity_users(id),
            revoked BOOLEAN NOT NULL DEFAULT FALSE)""")
        db.commit()

class Credentials(BaseModel):
    email: str
    password: str = Field(min_length=12, max_length=256)
    display_name: str = Field(default="", max_length=80)

def password_hash(password: str, salt: str) -> str:
    return hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=16384, r=8, p=1).hex()

def issue_session(db, user_id: str):
    token = secrets.token_urlsafe(40)
    db.execute("INSERT INTO identity_sessions VALUES (%s,%s,FALSE)", (hashlib.sha256(token.encode()).hexdigest(),user_id))
    return token

def get_identity(authorization: str):
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Missing bearer token")
    digest = hashlib.sha256(authorization[7:].encode()).hexdigest()
    with database() as db:
        row = db.execute("""SELECT u.id,u.email,u.display_name,u.is_guest,u.points
            FROM identity_sessions s JOIN identity_users u ON u.id=s.user_id
            WHERE s.token_hash=%s AND NOT s.revoked""", (digest,)).fetchone()
    if row is None:
        raise HTTPException(401, "Invalid session")
    return dict(zip(("id","email","display_name","is_guest","points"),row))

@app.get("/api/ready")
def ready():
    with database() as db:
        db.execute("SELECT 1")
    return {"ready": True}

@app.post("/api/auth/register", status_code=201)
def register(body: Credentials):
    salt = secrets.token_hex(16)
    uid = str(uuid.uuid4())
    with database() as db:
        exists = db.execute("SELECT 1 FROM identity_users WHERE email=%s",(body.email.lower(),)).fetchone()
        if exists:
            raise HTTPException(409,"Email already registered")
        db.execute("INSERT INTO identity_users (id,email,display_name,password_hash,salt) VALUES (%s,%s,%s,%s,%s)",
            (uid,body.email.lower(),body.display_name or body.email.split("@")[0],password_hash(body.password,salt),salt))
        token = issue_session(db,uid)
        db.commit()
    return {"access_token":token,"token_type":"bearer"}

@app.post("/api/auth/login")
def login(body: Credentials):
    with database() as db:
        row = db.execute("SELECT id,password_hash,salt FROM identity_users WHERE email=%s AND NOT is_guest",(body.email.lower(),)).fetchone()
        if not row or not secrets.compare_digest(password_hash(body.password,row[2]),row[1]):
            raise HTTPException(401,"Invalid credentials")
        token = issue_session(db,row[0])
        db.commit()
    return {"access_token":token,"token_type":"bearer"}

@app.post("/api/auth/guest", status_code=201)
def guest():
    uid = str(uuid.uuid4())
    with database() as db:
        db.execute("INSERT INTO identity_users (id,display_name,is_guest) VALUES (%s,%s,TRUE)",(uid,"Guest"))
        token=issue_session(db,uid)
        db.commit()
    return {"access_token":token,"token_type":"bearer"}

@app.get("/api/me")
def me(authorization: str = Header(default="")):
    return {"user":get_identity(authorization)}

@app.post("/api/auth/logout")
def logout(authorization: str = Header(default="")):
    identity=get_identity(authorization)
    digest=hashlib.sha256(authorization[7:].encode()).hexdigest()
    with database() as db:
        db.execute("UPDATE identity_sessions SET revoked=TRUE WHERE token_hash=%s AND user_id=%s",(digest,identity["id"]))
        db.commit()
    return {"ok":True}

@app.post("/api/auth/upgrade")
def upgrade(body: Credentials, authorization: str = Header(default="")):
    identity=get_identity(authorization)
    if not identity["is_guest"]:
        raise HTTPException(409,"Account is already registered")
    salt=secrets.token_hex(16)
    with database() as db:
        if db.execute("SELECT 1 FROM identity_users WHERE email=%s",(body.email.lower(),)).fetchone():
            raise HTTPException(409,"Email already registered")
        db.execute("""UPDATE identity_users SET email=%s,display_name=%s,password_hash=%s,salt=%s,is_guest=FALSE
            WHERE id=%s""",(body.email.lower(),body.display_name or "Player",password_hash(body.password,salt),salt,identity["id"]))
        token=issue_session(db,identity["id"])
        db.commit()
    return {"access_token":token,"token_type":"bearer"}

class AwardPoints(BaseModel):
    match_id: str = Field(min_length=8, max_length=120)
    points: int = Field(ge=1, le=100)

@app.post("/api/admin/award-points")
def award_points(body: AwardPoints, authorization: str = Header(default=""), x_admin_key: str = Header(default="")):
    """Internal server-only endpoint: never embed admin key in an APK."""
    configured = os.environ.get("GAMINGHUB_INTERNAL_ADMIN_KEY", "")
    if not configured or not secrets.compare_digest(x_admin_key, configured):
        raise HTTPException(403, "Forbidden")
    identity = get_identity(authorization)
    with database() as db:
        db.execute("""CREATE TABLE IF NOT EXISTS identity_awards (
            match_id TEXT NOT NULL, user_id TEXT NOT NULL REFERENCES identity_users(id),
            points INTEGER NOT NULL, PRIMARY KEY(match_id,user_id))""")
        inserted = db.execute("""INSERT INTO identity_awards (match_id,user_id,points)
            VALUES (%s,%s,%s) ON CONFLICT DO NOTHING RETURNING points""",
            (body.match_id,identity["id"],body.points)).fetchone()
        if inserted:
            db.execute("UPDATE identity_users SET points=points+%s WHERE id=%s",(body.points,identity["id"]))
        total = db.execute("SELECT points FROM identity_users WHERE id=%s",(identity["id"],)).fetchone()[0]
        db.commit()
    return {"awarded": bool(inserted), "points": total}


@app.get("/admin/dashboard", include_in_schema=False)
def admin_dashboard():
    """Serve the admin UI from the API origin so authenticated requests avoid CORS."""
    from pathlib import Path
    from fastapi.responses import HTMLResponse
    return HTMLResponse((Path(__file__).parent / "admin_dashboard.html").read_text(encoding="utf-8"))
