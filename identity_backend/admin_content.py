"""Server-only admin content draft management for Gaming Hub.

Never expose GAMINGHUB_INTERNAL_ADMIN_KEY in the Android application.
Drafts are not automatically published to gameplay.
"""
import json
import os
import secrets
import uuid

import psycopg
from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/admin/content", tags=["admin-content"])
DATABASE_URL = os.environ.get("GAMINGHUB_DATABASE_URL", "")


class ContentDraft(BaseModel):
    category: str = Field(pattern="^(image|question|sound)$")
    title: str = Field(min_length=1, max_length=160)
    payload: dict = Field(default_factory=dict)


def authorize(key: str):
    configured = os.environ.get("GAMINGHUB_INTERNAL_ADMIN_KEY", "")
    if not configured or not secrets.compare_digest(key, configured):
        raise HTTPException(403, "Forbidden")


def ensure_table(db):
    db.execute("""CREATE TABLE IF NOT EXISTS admin_content_drafts (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL CHECK (category IN ('image','question','sound')),
        title TEXT NOT NULL,
        payload JSONB NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )""")


@router.post("", status_code=201)
def create_draft(body: ContentDraft, x_admin_key: str = Header(default="")):
    authorize(x_admin_key)
    draft_id = str(uuid.uuid4())
    with psycopg.connect(DATABASE_URL) as db:
        ensure_table(db)
        db.execute(
            "INSERT INTO admin_content_drafts (id,category,title,payload) VALUES (%s,%s,%s,%s::jsonb)",
            (draft_id, body.category, body.title, json.dumps(body.payload)),
        )
        db.commit()
    return {"id": draft_id, "status": "draft"}


@router.get("")
def list_drafts(category: str | None = None, x_admin_key: str = Header(default="")):
    authorize(x_admin_key)
    if category is not None and category not in ("image", "question", "sound"):
        raise HTTPException(422, "Invalid category")
    with psycopg.connect(DATABASE_URL) as db:
        ensure_table(db)
        rows = db.execute(
            "SELECT id,category,title,payload FROM admin_content_drafts "
            "WHERE (%s::text IS NULL OR category=%s) ORDER BY created_at DESC LIMIT 200",
            (category, category),
        ).fetchall()
    return {"drafts": [{"id": r[0], "category": r[1], "title": r[2], "payload": r[3]} for r in rows]}


@router.put("/{draft_id}")
def update_draft(draft_id: str, body: ContentDraft, x_admin_key: str = Header(default="")):
    authorize(x_admin_key)
    with psycopg.connect(DATABASE_URL) as db:
        ensure_table(db)
        updated = db.execute(
            "UPDATE admin_content_drafts SET category=%s,title=%s,payload=%s::jsonb,updated_at=NOW() "
            "WHERE id=%s RETURNING id",
            (body.category, body.title, json.dumps(body.payload), draft_id),
        ).fetchone()
        if not updated:
            raise HTTPException(404, "Draft not found")
        db.commit()
    return {"id": draft_id, "status": "draft"}


@router.delete("/{draft_id}")
def delete_draft(draft_id: str, x_admin_key: str = Header(default="")):
    authorize(x_admin_key)
    with psycopg.connect(DATABASE_URL) as db:
        ensure_table(db)
        removed = db.execute(
            "DELETE FROM admin_content_drafts WHERE id=%s RETURNING id", (draft_id,)
        ).fetchone()
        if not removed:
            raise HTTPException(404, "Draft not found")
        db.commit()
    return {"deleted": True}
