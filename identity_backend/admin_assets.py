"""Protected binary asset staging for Gaming Hub content drafts.

Uploaded assets remain private and are never automatically published to gameplay.
"""
import hashlib
import os
import secrets
import uuid

import psycopg
from fastapi import APIRouter, Header, HTTPException, Request
from fastapi.responses import Response

router = APIRouter(prefix="/api/admin/assets", tags=["admin-assets"])
MAX_UPLOAD_BYTES = 8 * 1024 * 1024


def authorize(key: str):
    configured = os.environ.get("GAMINGHUB_INTERNAL_ADMIN_KEY", "")
    if not configured or not secrets.compare_digest(configured, key):
        raise HTTPException(403, "Forbidden")


def detect_media(data: bytes):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png", "image"
    if data.startswith(b"\xff\xd8\xff") and data.endswith(b"\xff\xd9"):
        return "image/jpeg", "image"
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "image/webp", "image"
    if data.startswith(b"RIFF") and data[8:12] == b"WAVE":
        return "audio/wav", "sound"
    if data.startswith(b"ID3") or (len(data) > 2 and data[0] == 0xFF and (data[1] & 0xE0) == 0xE0):
        return "audio/mpeg", "sound"
    if data.startswith(b"OggS"):
        return "audio/ogg", "sound"
    return None, None


def ensure_table(db):
    db.execute("""CREATE TABLE IF NOT EXISTS admin_staged_assets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL CHECK (category IN ('image','sound')),
        mime_type TEXT NOT NULL,
        sha256 TEXT NOT NULL,
        data BYTEA NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )""")


@router.post("", status_code=201)
async def upload_asset(request: Request, x_admin_key: str = Header(default="")):
    authorize(x_admin_key)
    if request.headers.get("content-length"):
        try:
            if int(request.headers["content-length"]) > MAX_UPLOAD_BYTES:
                raise HTTPException(413, "File too large")
        except ValueError:
            raise HTTPException(400, "Invalid content length")
    chunks = []
    total = 0
    async for chunk in request.stream():
        total += len(chunk)
        if total > MAX_UPLOAD_BYTES:
            raise HTTPException(413, "File too large")
        chunks.append(chunk)
    data = b"".join(chunks)
    mime_type, category = detect_media(data)
    if not category:
        raise HTTPException(415, "Unsupported file format")
    asset_id = str(uuid.uuid4())
    digest = hashlib.sha256(data).hexdigest()
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        ensure_table(db)
        db.execute(
            "INSERT INTO admin_staged_assets(id,category,mime_type,sha256,data) VALUES (%s,%s,%s,%s,%s)",
            (asset_id, category, mime_type, digest, data),
        )
        db.commit()
    return {"id": asset_id, "category": category, "mime_type": mime_type, "sha256": digest, "bytes": len(data), "status": "staged"}


@router.get("/{asset_id}")
def download_asset(asset_id: str, x_admin_key: str = Header(default="")):
    authorize(x_admin_key)
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        ensure_table(db)
        row = db.execute("SELECT mime_type,data FROM admin_staged_assets WHERE id=%s", (asset_id,)).fetchone()
    if row is None:
        raise HTTPException(404, "Asset not found")
    return Response(content=bytes(row[1]), media_type=row[0], headers={"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"})


@router.delete("/{asset_id}")
def delete_asset(asset_id: str, x_admin_key: str = Header(default="")):
    authorize(x_admin_key)
    with psycopg.connect(os.environ["GAMINGHUB_DATABASE_URL"]) as db:
        ensure_table(db)
        # Do not orphan content drafts that reference this binary.
        from identity_backend.admin_content import ensure_table as ensure_drafts
        ensure_drafts(db)
        referenced = db.execute(
            "SELECT 1 FROM admin_content_drafts WHERE payload->>'staged_asset_id'=%s LIMIT 1",
            (asset_id,),
        ).fetchone()
        if referenced:
            raise HTTPException(409, "Asset is referenced by a content draft")
        removed = db.execute("DELETE FROM admin_staged_assets WHERE id=%s RETURNING id", (asset_id,)).fetchone()
        if not removed:
            raise HTTPException(404, "Asset not found")
        db.commit()
    return {"deleted": True}
