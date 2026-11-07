"""Optional server-side account binding for websocket sessions.

Never trust a player ID supplied in game messages. Verify the bearer session
against the identity database, then bind the returned user ID to the connection.
"""
import hashlib
from dataclasses import dataclass

@dataclass(frozen=True)
class BoundIdentity:
    user_id: str
    display_name: str = ""
    avatar_url: str = ""

def verify_session(database_url: str, token: str):
    if not isinstance(token, str) or len(token) < 32 or len(token) > 512:
        return None
    import psycopg
    digest = hashlib.sha256(token.encode()).hexdigest()
    with psycopg.connect(database_url,connect_timeout=3) as db:
        row = db.execute("""SELECT s.user_id,u.display_name,u.avatar_url FROM identity_sessions s
            JOIN identity_users u ON u.id=s.user_id
            WHERE s.token_hash=%s AND NOT s.revoked AND s.expires_at>CURRENT_TIMESTAMP""",(digest,)).fetchone()
    return BoundIdentity(*row) if row else None

class SessionBindings:
    def __init__(self):
        self._connections = {}

    def bind_verified(self, connection, identity):
        if not isinstance(identity, BoundIdentity):
            raise ValueError("Only verified identities may be bound")
        self._connections[connection] = identity

    def account_for(self, connection):
        identity = self._connections.get(connection)
        return identity.user_id if identity else None

    def disconnect(self, connection):
        self._connections.pop(connection, None)
