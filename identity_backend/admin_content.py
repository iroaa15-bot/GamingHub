"""Server-only admin content draft management for Gaming Hub.

Never expose GAMINGHUB_INTERNAL_ADMIN_KEY in the Android application.
Drafts are not automatically published to gameplay.
"""
import json
import os
import secrets
import uuid

import psycopg
from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/admin/content", tags=["admin-content"])
DATABASE_URL = os.environ.get("GAMINGHUB_DATABASE_URL", "")


class ContentDraft(BaseModel):
    category: str = Field(pattern="^(image|question|sound)$")
    title: str = Field(min_length=1, max_length=160)
    payload: dict = Field(default_factory=dict)


from identity_backend.admin_auth import authorize_admin


def ensure_table(db):
    db.execute("""CREATE TABLE IF NOT EXISTS admin_content_drafts (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL CHECK (category IN ('image','question','sound')),
        title TEXT NOT NULL,
        payload JSONB NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )""")

    db.execute("ALTER TABLE admin_content_drafts ADD COLUMN IF NOT EXISTS review_status TEXT NOT NULL DEFAULT 'draft'")


def validate_staged_asset(db, body: ContentDraft):
    """Validate an optional staged binary reference before storing the draft."""
    asset_id = body.payload.get("staged_asset_id")
    if asset_id is None:
        return
    if not isinstance(asset_id, str):
        raise HTTPException(422, "staged_asset_id must be a string")
    try:
        uuid.UUID(asset_id)
    except (ValueError, AttributeError):
        raise HTTPException(422, "Invalid staged asset ID")
    # This table may not exist until the first upload.
    from identity_backend.admin_assets import ensure_table as ensure_assets
    ensure_assets(db)
    row = db.execute(
        "SELECT category FROM admin_staged_assets WHERE id=%s", (asset_id,)
    ).fetchone()
    if row is None:
        raise HTTPException(422, "Staged asset not found")
    if body.category in ("image", "sound") and row[0] != body.category:
        raise HTTPException(422, "Staged asset category mismatch")



@router.post("/{draft_id}/review/{decision}")
def review_draft(draft_id: str, decision: str, request: Request, x_admin_key: str = Header(default="")):
    authorize_admin(request, x_admin_key)
    transitions = {"submit": ("draft", "in_review"), "approve": ("in_review", "approved"),
                   "reject": ("in_review", "rejected"), "resubmit": ("rejected", "in_review")}
    if decision not in transitions:
        raise HTTPException(422, "Invalid review decision")
    previous, next_status = transitions[decision]
    with psycopg.connect(DATABASE_URL) as db:
        ensure_table(db)
        db.execute("ALTER TABLE admin_content_drafts ADD COLUMN IF NOT EXISTS review_status TEXT NOT NULL DEFAULT 'draft'")
        row = db.execute(
            "UPDATE admin_content_drafts SET review_status=%s,updated_at=NOW() WHERE id=%s AND review_status=%s RETURNING id",
            (next_status, draft_id, previous),
        ).fetchone()
        if row is None:
            raise HTTPException(409, "Draft missing or invalid review transition")
        db.commit()
    return {"id": draft_id, "review_status": next_status}


@router.post("/{draft_id}/validate")
def validate_draft(draft_id: str, request: Request, x_admin_key: str = Header(default="")):
    authorize_admin(request, x_admin_key)
    from identity_backend.gameplay_content import question_projection
    with psycopg.connect(DATABASE_URL) as db:
        ensure_table(db)
        row = db.execute("SELECT category,title,payload FROM admin_content_drafts WHERE id=%s", (draft_id,)).fetchone()
        if not row:
            raise HTTPException(404, "Draft not found")
        if question_projection(draft_id, row[0], row[2]) is None:
            raise HTTPException(422, "Question fields are incomplete or incompatible with the game")
        if row[0] in ("image", "sound"):
            validate_staged_asset(db, ContentDraft(category=row[0], title=row[1], payload=row[2]))
            from identity_backend.admin_assets import ensure_table as ensure_assets
            ensure_assets(db)
            asset = db.execute("SELECT mime_type FROM admin_staged_assets WHERE id=%s", (row[2].get("staged_asset_id", ""),)).fetchone()
            allowed = ("image/png", "image/jpeg", "image/webp") if row[0] == "image" else ("audio/wav",)
            if not asset or asset[0] not in allowed:
                raise HTTPException(422, "Attach a supported gameplay media file")
    return {"valid": True}


@router.post("", status_code=201)
def create_draft(body: ContentDraft, request: Request, x_admin_key: str = Header(default="")):
    authorize_admin(request, x_admin_key)
    draft_id = str(uuid.uuid4())
    with psycopg.connect(DATABASE_URL) as db:
        ensure_table(db)
        validate_staged_asset(db, body)
        db.execute(
            "INSERT INTO admin_content_drafts (id,category,title,payload) VALUES (%s,%s,%s,%s::jsonb)",
            (draft_id, body.category, body.title, json.dumps(body.payload)),
        )
        db.commit()
    return {"id": draft_id, "status": "draft"}


@router.get("")
def list_drafts(request: Request, category: str | None = None, x_admin_key: str = Header(default="")):
    authorize_admin(request, x_admin_key)
    if category is not None and category not in ("image", "question", "sound"):
        raise HTTPException(422, "Invalid category")
    with psycopg.connect(DATABASE_URL) as db:
        ensure_table(db)
        rows = db.execute(
            "SELECT id,category,title,payload,review_status FROM admin_content_drafts "
            "WHERE (%s::text IS NULL OR category=%s) ORDER BY created_at DESC LIMIT 200",
            (category, category),
        ).fetchall()
    return {"drafts": [{"id": r[0], "category": r[1], "title": r[2], "payload": r[3], "review_status": r[4]} for r in rows]}


@router.put("/{draft_id}")
def update_draft(draft_id: str, body: ContentDraft, request: Request, x_admin_key: str = Header(default="")):
    authorize_admin(request, x_admin_key)
    with psycopg.connect(DATABASE_URL) as db:
        ensure_table(db)
        validate_staged_asset(db, body)
        updated = db.execute(
            "UPDATE admin_content_drafts SET category=%s,title=%s,payload=%s::jsonb,review_status='draft',updated_at=NOW() "
            "WHERE id=%s RETURNING id",
            (body.category, body.title, json.dumps(body.payload), draft_id),
        ).fetchone()
        if not updated:
            raise HTTPException(404, "Draft not found")
        db.commit()
    return {"id": draft_id, "status": "draft"}


@router.delete("/{draft_id}")
def delete_draft(draft_id: str, request: Request, x_admin_key: str = Header(default="")):
    authorize_admin(request, x_admin_key)
    with psycopg.connect(DATABASE_URL) as db:
        ensure_table(db)
        removed = db.execute(
            "DELETE FROM admin_content_drafts WHERE id=%s RETURNING id", (draft_id,)
        ).fetchone()
        if not removed:
            raise HTTPException(404, "Draft not found")
        db.commit()
    return {"deleted": True}
