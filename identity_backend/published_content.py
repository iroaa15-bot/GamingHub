"""Versioned content publishing, isolated from editable drafts.

Publishing is a server-side action. Revocation removes an item from the public
feed without deleting the audit record.
"""
import json
import hashlib
import os
import secrets
import uuid

import psycopg
from fastapi import APIRouter, Header, HTTPException

router = APIRouter(tags=["published-content"])


def authorize(key):
    expected = os.environ.get("GAMINGHUB_INTERNAL_ADMIN_KEY", "")
    if not expected or not secrets.compare_digest(key, expected):
        raise HTTPException(403, "Forbidden")


def ensure_table(db):
    db.execute("""CREATE TABLE IF NOT EXISTS published_content (
        id TEXT PRIMARY KEY,
        draft_id TEXT NOT NULL,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        payload JSONB NOT NULL,
        active BOOLEAN NOT NULL DEFAULT TRUE,
        published_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        revoked_at TIMESTAMPTZ
    )""")
    for column in ("asset_mime TEXT", "asset_data BYTEA", "asset_sha256 TEXT"):
        db.execute("ALTER TABLE published_content ADD COLUMN IF NOT EXISTS "+column)
    db.execute("CREATE INDEX IF NOT EXISTS published_content_active_idx ON published_content(category,active,published_at)")


@router.post("/api/admin/content/{draft_id}/publish", status_code=201)
def publish(draft_id: str, x_admin_key: str = Header(default="")):
    authorize(x_admin_key)
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        ensure_table(db)
        from identity_backend.admin_content import ensure_table as ensure_drafts
        ensure_drafts(db)
        row = db.execute(
            "SELECT category,title,payload,review_status FROM admin_content_drafts WHERE id=%s FOR UPDATE",
            (draft_id,),
        ).fetchone()
        if row is None:
            raise HTTPException(404, "Draft not found")
        if row[3] != "approved":
            raise HTTPException(409, "Only approved drafts can be published")
        asset = None
        if row[2].get("staged_asset_id"):
            from identity_backend.admin_assets import ensure_table as ensure_assets
            ensure_assets(db)
            asset = db.execute("SELECT mime_type,data FROM admin_staged_assets WHERE id=%s FOR SHARE", (row[2]["staged_asset_id"],)).fetchone()
            if asset is None:raise HTTPException(422,"Staged asset no longer exists")
            # Bound decoded size before a public client ever sees the binary.
            import io
            try:
                if asset[0].startswith('image/'):
                    from PIL import Image
                    with Image.open(io.BytesIO(bytes(asset[1]))) as image:
                        if image.width>2048 or image.height>2048:raise ValueError()
                        image.verify()
                elif asset[0]=='audio/wav':
                    import wave
                    with wave.open(io.BytesIO(bytes(asset[1]))) as audio:
                        if audio.getnchannels() not in (1,2) or audio.getframerate()>48000 or audio.getnframes()/audio.getframerate()>60:raise ValueError()
            except Exception:
                raise HTTPException(422,'Media cannot be decoded within gameplay limits')
        published_id = str(uuid.uuid4())
        db.execute(
            "INSERT INTO published_content(id,draft_id,category,title,payload) VALUES (%s,%s,%s,%s,%s::jsonb)",
            (published_id, draft_id, row[0], row[1], json.dumps(row[2])),
        )
        if asset:
            db.execute("UPDATE published_content SET asset_mime=%s,asset_data=%s,asset_sha256=%s WHERE id=%s",
                       (asset[0],asset[1],hashlib.sha256(bytes(asset[1])).hexdigest(),published_id))
        db.commit()
    return {"id": published_id, "draft_id": draft_id, "status": "published"}


@router.post("/api/admin/published/{published_id}/revoke")
def revoke(published_id: str, x_admin_key: str = Header(default="")):
    authorize(x_admin_key)
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        ensure_table(db)
        row = db.execute(
            "UPDATE published_content SET active=FALSE,revoked_at=NOW() "
            "WHERE id=%s AND active=TRUE RETURNING id",
            (published_id,),
        ).fetchone()
        if row is None:
            raise HTTPException(404, "Active published item not found")
        db.commit()
    return {"id": published_id, "status": "revoked"}


@router.get("/api/content")
def public_content(category: str | None = None, limit: int = 50):
    if category is not None and category not in ("image", "question", "sound"):
        raise HTTPException(422, "Invalid category")
    if not 1 <= limit <= 100:
        raise HTTPException(422, "Limit must be between 1 and 100")
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        ensure_table(db)
        rows = db.execute(
            "SELECT id,category,title,payload FROM published_content "
            "WHERE active=TRUE AND (%s::text IS NULL OR category=%s) "
            "ORDER BY published_at DESC,id DESC LIMIT %s",
            (category, category, limit),
        ).fetchall()
    return {"items": [{"id": r[0], "category": r[1], "title": r[2], "payload": r[3]} for r in rows]}
