"""Guest-session authentication and moderation storage for the isolated service only."""
import base64, hashlib, hmac, json, secrets, sqlite3, time
from collections import defaultdict, deque

def encode(raw): return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()
def decode(value): return base64.urlsafe_b64decode(value+"="*(-len(value)%4))

class Sessions:
    def __init__(self, secret, ttl=21600):
        if len(secret.encode())<32: raise ValueError("DUEL_AUTH_SECRET must contain at least 32 bytes")
        self.secret=secret.encode();self.ttl=ttl
    def issue(self):
        claims={"sub":secrets.token_hex(16),"exp":int(time.time())+self.ttl,"aud":"gaminghub-duel","terms":"1"}
        payload=encode(json.dumps(claims,separators=(",",":")).encode())
        return payload+"."+encode(hmac.digest(self.secret,payload.encode(),"sha256")),claims
    def verify(self, token):
        try:
            if not isinstance(token,str) or len(token)>2048: raise ValueError()
            payload,signature=token.split(".")
            if not hmac.compare_digest(hmac.digest(self.secret,payload.encode(),"sha256"),decode(signature)):raise ValueError()
            claims=json.loads(decode(payload))
            if claims.get("aud")!="gaminghub-duel" or claims.get("terms")!="1" or type(claims.get("exp")) is not int or claims["exp"]<=time.time():raise ValueError()
            if not isinstance(claims.get("sub"),str) or len(claims["sub"])!=32:raise ValueError()
            return claims
        except Exception: raise ValueError("Invalid or expired session") from None

class Limits:
    def __init__(self):self.events={}
    def admit(self, key, limit, seconds):
        now=time.monotonic()
        if len(self.events)>10000:
            self.events={k:v for k,v in self.events.items() if v and now-v[-1]<60}
            if key not in self.events and len(self.events)>10000:return False
        values=self.events.setdefault(key,deque())
        while values and now-values[0]>seconds:values.popleft()
        if len(values)>=limit:return False
        values.append(now);return True

class Moderation:
    def __init__(self, path):
        self.db=sqlite3.connect(path)
        self.db.executescript("CREATE TABLE IF NOT EXISTS blocks(owner TEXT,target TEXT,PRIMARY KEY(owner,target));CREATE TABLE IF NOT EXISTS reports(id TEXT PRIMARY KEY,created INTEGER,reporter TEXT,target TEXT,reason TEXT);")
    def blocked(self,a,b):return self.db.execute("SELECT 1 FROM blocks WHERE (owner=? AND target=?) OR (owner=? AND target=?)",(a,b,b,a)).fetchone() is not None
    def block(self,a,b):
        self.db.execute("INSERT OR IGNORE INTO blocks VALUES(?,?)",(a,b));self.db.commit()
    def report(self,a,b,reason):
        identifier=secrets.token_hex(8)
        self.db.execute("INSERT INTO reports VALUES(?,?,?,?,?)",(identifier,int(time.time()),a,b,reason));self.db.commit();return identifier
