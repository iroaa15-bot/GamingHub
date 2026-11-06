"""Bounded, metadata-free player avatars persisted with the existing account DB."""
import base64
import binascii
import hashlib
import io
import warnings

from fastapi import APIRouter, Header, HTTPException
from fastapi.responses import Response
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, ConfigDict, Field

router = APIRouter(tags=["player-avatar"])

def initialize_avatar(db):
    db.execute("""CREATE TABLE IF NOT EXISTS identity_avatars (
        user_id TEXT PRIMARY KEY REFERENCES identity_users(id) ON DELETE CASCADE,
        digest TEXT NOT NULL, data BYTEA NOT NULL)""")

class AvatarUpload(BaseModel):
    model_config = ConfigDict(extra="forbid")
    image_base64: str = Field(min_length=16, max_length=1000000)

def normalize_avatar(encoded):
    try:
        data = base64.b64decode(encoded, validate=True)
        if len(data)>750000:
            raise ValueError("Image too large")
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as original:
                if original.format not in ("PNG","JPEG","WEBP") or getattr(original,"n_frames",1)!=1:
                    raise ValueError("Unsupported image")
                if original.width*original.height>16000000 or min(original.size)<16:
                    raise ValueError("Unsupported dimensions")
                image = ImageOps.fit(ImageOps.exif_transpose(original).convert("RGB"),(256,256))
                output = io.BytesIO()
                image.save(output,format="JPEG",quality=85,optimize=True)
        return output.getvalue()
    except (ValueError, OSError, binascii.Error, UnidentifiedImageError,
            Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise HTTPException(422,"Choose a supported still image") from None

@router.post("/api/me/avatar")
def upload_avatar(body: AvatarUpload, authorization: str=Header(default="")):
    from identity_backend.app import database, get_identity
    user = get_identity(authorization)
    data = normalize_avatar(body.image_base64)
    digest = hashlib.sha256(data).hexdigest()
    url = "/api/avatars/"+user["id"]+"/"+digest+".jpg"
    with database() as db:
        db.execute("""INSERT INTO identity_avatars VALUES (%s,%s,%s)
            ON CONFLICT(user_id) DO UPDATE SET digest=EXCLUDED.digest,data=EXCLUDED.data""",
            (user["id"],digest,data))
        db.execute("UPDATE identity_users SET avatar_url=%s WHERE id=%s",(url,user["id"]))
        db.commit()
    from identity_backend.app import me
    return me(authorization)

@router.get("/api/avatars/{user_id}/{filename}")
def avatar(user_id: str, filename: str):
    from identity_backend.app import database
    if len(user_id)>80 or len(filename)!=68 or not filename.endswith(".jpg"):
        raise HTTPException(404,"Image unavailable")
    with database() as db:
        row = db.execute("SELECT data FROM identity_avatars WHERE user_id=%s AND digest=%s",
                         (user_id,filename[:-4])).fetchone()
    if not row:
        raise HTTPException(404,"Image unavailable")
    return Response(bytes(row[0]),media_type="image/jpeg",headers={
        "Cache-Control":"private, max-age=300", "X-Content-Type-Options":"nosniff"})
