"""Versioned, data-only game presentation. No executable settings or player data."""
import json
from copy import deepcopy

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, StrictBool, StrictInt, field_validator

from identity_backend.admin_auth import authorize_admin, database

router = APIRouter(tags=["appearance"])


class Appearance(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    background: str = "#030a28"
    background_end: str = "#121044"
    primary: str = "#0c1d51"
    custom_primary: StrictBool = False
    font_scale: float = Field(default=1.0, ge=0.9, le=1.25)
    home_columns: StrictInt = Field(default=0, ge=0, le=3)
    primary_count: StrictInt = Field(default=6, ge=1, le=10)
    game_order: list[StrictInt] = Field(default_factory=lambda: [0, 1, 6, 3, 8, 9, 2, 4, 5, 7], min_length=10, max_length=10)
    enabled_games: list[StrictInt] = Field(default_factory=lambda: list(range(10)), min_length=1, max_length=10)
    title_ar: str = Field(default="Gaming Hub • الألعاب", min_length=1, max_length=80)
    title_en: str = Field(default="Gaming Hub • GAMES", min_length=1, max_length=80)
    notice_ar: str = Field(default="", max_length=160)
    notice_en: str = Field(default="", max_length=160)
    show_activities: StrictBool = True

    @field_validator("background", "background_end", "primary")
    @classmethod
    def readable_color(cls, value):
        import re
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
            raise ValueError("Use a six-digit hex color")
        channels = [int(value[i:i+2], 16) / 255 for i in (1, 3, 5)]
        linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in channels]
        luminance = sum(a*b for a,b in zip(linear, (.2126, .7152, .0722)))
        if 1.05 / (luminance + .05) < 4.5:
            raise ValueError("Choose a darker color so white text remains readable")
        return value.lower()

    @field_validator("game_order", "enabled_games")
    @classmethod
    def unique_games(cls, value):
        if len(value) != len(set(value)) or any(v not in range(10) for v in value):
            raise ValueError("Only unique built-in game IDs 0 through 9 are supported")
        return value


class SaveAppearance(BaseModel):
    model_config = ConfigDict(extra="forbid")
    expected_revision: StrictInt = Field(ge=0)
    settings: Appearance


class PublishAppearance(BaseModel):
    expected_revision: StrictInt = Field(ge=0)


def initialize_appearance(db):
    db.execute("""CREATE TABLE IF NOT EXISTS game_appearance_draft (
        singleton INTEGER PRIMARY KEY CHECK(singleton=1), revision BIGINT NOT NULL,
        settings JSONB NOT NULL, updated_by TEXT NOT NULL, updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW())""")
    db.execute("""CREATE TABLE IF NOT EXISTS game_appearance_versions (
        version BIGSERIAL PRIMARY KEY, settings JSONB NOT NULL, published_by TEXT NOT NULL,
        published_at TIMESTAMPTZ NOT NULL DEFAULT NOW())""")
    db.execute("INSERT INTO game_appearance_draft(singleton,revision,settings,updated_by) VALUES(1,0,%s::jsonb,'initial') ON CONFLICT DO NOTHING", (json.dumps(Appearance().model_dump()),))


@router.get("/api/config")
def public_config():
    with database() as db:
        row = db.execute("SELECT version,settings FROM game_appearance_versions ORDER BY version DESC LIMIT 1").fetchone()
    return {"schema": 1, "version": row[0] if row else 0, "settings": row[1] if row else Appearance().model_dump()}


@router.get("/api/admin/appearance")
def get_appearance(request: Request, x_admin_key: str = Header(default="")):
    authorize_admin(request, x_admin_key)
    with database() as db:
        draft = db.execute("SELECT revision,settings FROM game_appearance_draft WHERE singleton=1").fetchone()
        history = db.execute("SELECT version,settings,published_at FROM game_appearance_versions ORDER BY version DESC LIMIT 20").fetchall()
    return {"revision": draft[0], "draft": draft[1], "defaults": Appearance().model_dump(),
            "history": [{"version": r[0], "settings": r[1], "published_at": r[2].isoformat()} for r in history]}


@router.put("/api/admin/appearance")
def save_appearance(body: SaveAppearance, request: Request, x_admin_key: str = Header(default="")):
    actor = authorize_admin(request, x_admin_key)
    with database() as db:
        row = db.execute("""UPDATE game_appearance_draft SET revision=revision+1,settings=%s::jsonb,updated_by=%s,updated_at=NOW()
            WHERE singleton=1 AND revision=%s RETURNING revision""", (body.settings.model_dump_json(), actor, body.expected_revision)).fetchone()
        if not row:
            raise HTTPException(409, "Settings changed in another window; reload before saving")
        db.commit()
    return {"revision": row[0]}


@router.post("/api/admin/appearance/publish")
def publish_appearance(body: PublishAppearance, request: Request, x_admin_key: str = Header(default="")):
    actor = authorize_admin(request, x_admin_key)
    with database() as db:
        draft = db.execute("SELECT revision,settings FROM game_appearance_draft WHERE singleton=1 FOR UPDATE").fetchone()
        if draft[0] != body.expected_revision:
            raise HTTPException(409, "Settings changed; reload before publishing")
        Appearance.model_validate(draft[1])
        previous = db.execute("SELECT version,settings FROM game_appearance_versions ORDER BY version DESC LIMIT 1").fetchone()
        if previous and previous[1] == draft[1]:
            return {"version": previous[0]}
        row = db.execute("INSERT INTO game_appearance_versions(settings,published_by) VALUES(%s::jsonb,%s) RETURNING version", (json.dumps(draft[1]), actor)).fetchone()
        db.commit()
    return {"version": row[0]}


@router.post("/api/admin/appearance/rollback/{version}")
def rollback_appearance(version: int, request: Request, x_admin_key: str = Header(default="")):
    actor = authorize_admin(request, x_admin_key)
    with database() as db:
        db.execute("SELECT revision FROM game_appearance_draft WHERE singleton=1 FOR UPDATE")
        old = db.execute("SELECT settings FROM game_appearance_versions WHERE version=%s", (version,)).fetchone()
        if not old:
            raise HTTPException(404, "Unknown version")
        settings = Appearance.model_validate(old[0]).model_dump_json()
        row = db.execute("INSERT INTO game_appearance_versions(settings,published_by) VALUES(%s::jsonb,%s) RETURNING version", (settings, actor)).fetchone()
        db.execute("UPDATE game_appearance_draft SET revision=revision+1,settings=%s::jsonb,updated_by=%s,updated_at=NOW() WHERE singleton=1", (settings, actor))
        db.commit()
    return {"version": row[0], "restored_from": version}
