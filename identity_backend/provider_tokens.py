"""Provider verification boundary. No client-supplied profile or user ID is trusted."""
import hashlib
import hmac
import os
import time
from dataclasses import dataclass
from fastapi import HTTPException

@dataclass(frozen=True)
class ProviderIdentity:
    subject: str
    name: str
    email: str | None = None
    avatar: str = ""

def google_identity(token: str, nonce: str) -> ProviderIdentity:
    audience = os.environ.get("GAMINGHUB_GOOGLE_WEB_CLIENT_ID", "")
    if not audience:
        raise HTTPException(503, "Google sign-in is not configured")
    from google.oauth2 import id_token
    from google.auth.transport.requests import Request
    try:
        claims = id_token.verify_oauth2_token(token, Request(), audience=audience)
        if claims.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
            raise ValueError("issuer")
        if not hmac.compare_digest(str(claims.get("nonce", "")), nonce):
            raise ValueError("nonce")
        if not claims.get("sub") or int(claims.get("exp", 0)) <= time.time():
            raise ValueError("expired")
        return ProviderIdentity(str(claims["sub"]),str(claims.get("name", "Player"))[:80],
            str(claims["email"]).lower() if claims.get("email_verified") is True and claims.get("email") else None,
            str(claims.get("picture", ""))[:2048])
    except (ValueError, TypeError, KeyError):
        raise HTTPException(401,"Invalid Google identity token") from None

def facebook_identity(token: str) -> ProviderIdentity:
    app_id = os.environ.get("GAMINGHUB_FACEBOOK_APP_ID", "")
    secret = os.environ.get("GAMINGHUB_FACEBOOK_APP_SECRET", "")
    version = os.environ.get("GAMINGHUB_META_GRAPH_VERSION", "")
    if not app_id or not secret or not version:
        raise HTTPException(503,"Facebook sign-in is not configured")
    import httpx
    # The version must be explicitly selected against the configured Meta app.
    import re
    if not re.fullmatch(r"v\d+\.\d+", version):
        raise HTTPException(503,"Invalid Meta Graph API version")
    base = "https://graph.facebook.com/" + version
    try:
        with httpx.Client(timeout=8,follow_redirects=False) as client:
            response = client.get(base+"/debug_token",params={"input_token":token},
                headers={"Authorization":"Bearer "+app_id+"|"+secret})
            response.raise_for_status()
            data = response.json().get("data", {})
            if (not data.get("is_valid") or str(data.get("app_id")) != app_id
                or not data.get("user_id") or int(data.get("expires_at",0)) <= time.time()
                or int(data.get("data_access_expires_at",0)) <= time.time()):
                raise ValueError("Invalid token")
            proof = hmac.new(secret.encode(),token.encode(),hashlib.sha256).hexdigest()
            profile = client.get(base+"/me",params={"fields":"id,name,email,picture", "appsecret_proof":proof},
                headers={"Authorization":"Bearer "+token})
            profile.raise_for_status()
            user = profile.json()
            if str(user.get("id")) != str(data["user_id"]): raise ValueError("subject")
            return ProviderIdentity(str(data["user_id"]),str(user.get("name","Player"))[:80],
                str(user["email"]).lower() if user.get("email") else None,
                str(user.get("picture",{}).get("data",{}).get("url",""))[:2048])
    except (ValueError,TypeError,KeyError,httpx.HTTPError):
        # Do not leak HTTP exceptions containing provider tokens in request URLs.
        raise HTTPException(401,"Facebook token could not be verified") from None
