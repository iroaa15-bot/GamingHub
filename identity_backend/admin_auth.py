"""Dedicated owner login. Player sessions never confer administrative access."""
import hashlib
import os
import secrets
from urllib.parse import urlsplit

import psycopg
from fastapi import APIRouter, Header, HTTPException, Request, Response
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/admin/auth", tags=["admin-auth"])
COOKIE = "__Host-gh_admin"


def database():
    return psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"])


def initialize_admin(db):
    db.execute("""CREATE TABLE IF NOT EXISTS admin_owners (
        email TEXT PRIMARY KEY, password_hash TEXT NOT NULL, salt TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())""")
    db.execute("""CREATE TABLE IF NOT EXISTS admin_browser_sessions (
        digest TEXT PRIMARY KEY, email TEXT NOT NULL REFERENCES admin_owners(email),
        expires_at TIMESTAMPTZ NOT NULL, revoked BOOLEAN NOT NULL DEFAULT FALSE)""")
    db.execute("""CREATE TABLE IF NOT EXISTS admin_login_failures (
        email_hash TEXT NOT NULL, ip_hash TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())""")


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def browser_write(request):
    origin = urlsplit(request.headers.get("origin", ""))
    if (origin.scheme != "https" or origin.netloc != request.headers.get("host")
            or request.headers.get("x-gaminghub-admin") != "1"):
        raise HTTPException(403, "Reload the dashboard and try again")


def owner_session(request):
    token = request.cookies.get(COOKIE, "")
    if not token:
        raise HTTPException(401, "Admin sign-in required")
    with database() as db:
        row = db.execute("""SELECT email FROM admin_browser_sessions
            WHERE digest=%s AND NOT revoked AND expires_at>NOW()""", (digest(token),)).fetchone()
    if not row:
        raise HTTPException(401, "Admin session expired")
    return row[0]


def authorize_admin(request, key):
    # Compatibility for existing server-only jobs; never expose this key in the UI/APK.
    configured = os.environ.get("GAMINGHUB_INTERNAL_ADMIN_KEY", "")
    if configured and key and secrets.compare_digest(key, configured):
        return "internal-service"
    if not request.cookies.get(COOKIE):
        raise HTTPException(403, "Administrator access required")
    email = owner_session(request)
    if request.method not in ("GET", "HEAD"):
        browser_write(request)
    return email


class Login(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=12, max_length=256)


class Setup(Login):
    setup_token: str = Field(min_length=32, max_length=128)


def set_session(db, response, email):
    token = secrets.token_urlsafe(48)
    db.execute("DELETE FROM admin_browser_sessions WHERE expires_at<NOW() OR revoked")
    db.execute("""INSERT INTO admin_browser_sessions(digest,email,expires_at)
        VALUES(%s,%s,NOW()+INTERVAL '8 hours')""", (digest(token), email))
    response.set_cookie(COOKIE, token, max_age=28800, secure=True, httponly=True,
                        samesite="strict", path="/")
    response.headers["Cache-Control"] = "no-store"


@router.get("/status")
def status(response: Response):
    response.headers["Cache-Control"] = "no-store"
    with database() as db:
        configured = bool(db.execute("SELECT 1 FROM admin_owners LIMIT 1").fetchone())
    return {"configured": configured}


@router.post("/setup")
def setup(body: Setup, request: Request, response: Response):
    browser_write(request)
    expected = os.environ.get("GAMINGHUB_ADMIN_SETUP_TOKEN", "")
    email = os.environ.get("GAMINGHUB_ADMIN_OWNER_EMAIL", "").strip().lower()
    if (not expected or not email or body.email.strip().lower() != email
            or not secrets.compare_digest(body.setup_token, expected)):
        raise HTTPException(403, "Owner setup unavailable or invalid")
    from identity_backend.app import password_hash
    salt = secrets.token_hex(16)
    hashed = password_hash(body.password, salt)
    with database() as db:
        db.execute("SELECT pg_advisory_xact_lock(82059173)")
        if db.execute("SELECT 1 FROM admin_owners LIMIT 1").fetchone():
            raise HTTPException(409, "Owner already configured; use sign-in")
        db.execute("INSERT INTO admin_owners(email,password_hash,salt) VALUES(%s,%s,%s)",
                   (email, hashed, salt))
        set_session(db, response, email)
        db.commit()
    return {"email": email}


@router.post("/login")
def login(body: Login, request: Request, response: Response):
    browser_write(request)
    email = body.email.strip().lower()
    ip_hash = digest(request.client.host if request.client else "unknown")
    email_hash = digest(email)
    with database() as db:
        db.execute("DELETE FROM admin_login_failures WHERE created_at<NOW()-INTERVAL '15 minutes'")
        attempts = db.execute("""SELECT COUNT(*) FROM admin_login_failures
            WHERE email_hash=%s OR ip_hash=%s""", (email_hash, ip_hash)).fetchone()[0]
        if attempts >= 10:
            raise HTTPException(429, "Too many attempts; wait 15 minutes")
        row = db.execute("SELECT password_hash,salt FROM admin_owners WHERE email=%s", (email,)).fetchone()
        from identity_backend.app import password_hash
        actual = password_hash(body.password, row[1] if row else "00" * 16)
        if not row or not secrets.compare_digest(actual, row[0]):
            db.execute("INSERT INTO admin_login_failures(email_hash,ip_hash) VALUES(%s,%s)", (email_hash, ip_hash))
            db.commit()
            raise HTTPException(401, "Invalid administrator credentials")
        set_session(db, response, email)
        db.commit()
    return {"email": email}


@router.get("/me")
def me(request: Request, response: Response):
    response.headers["Cache-Control"] = "no-store"
    return {"email": owner_session(request)}


@router.post("/logout")
def logout(request: Request, response: Response):
    browser_write(request)
    with database() as db:
        db.execute("UPDATE admin_browser_sessions SET revoked=TRUE WHERE digest=%s", (digest(request.cookies.get(COOKIE, "")),))
        db.commit()
    response.delete_cookie(COOKIE, path="/", secure=True, httponly=True, samesite="strict")
    return {"ok": True}
