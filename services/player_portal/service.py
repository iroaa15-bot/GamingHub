"""Local-only player/admin service. No production imports or writes.
Start: python services/player_portal/service.py --db <private.sqlite> --port 8879
OAuth and remote hosting deliberately unavailable until configured and reviewed.
"""
import contextlib
import argparse, hashlib, hmac, json, re, secrets, sqlite3, threading, time
from collections import defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

class Fault(Exception):
 def __init__(self,status,message): self.status,self.message=status,message

def require(condition,message="Invalid request",status=400):
 if not condition: raise Fault(status,message)

def clean(value,limit=80):
 require(isinstance(value,str) and 0<len(value.strip())<=limit)
 require(not any(ord(c)<32 for c in value))
 return value.strip()

def password_hash(password,salt):
 require(isinstance(password,str) and 12<=len(password)<=256,"Password must contain 12–256 characters")
 return hashlib.pbkdf2_hmac("sha256",password.encode(),bytes.fromhex(salt),600000).hex()

class Store:
 def __init__(self,path):
  self.path=path;self.started=time.time();self.lock=threading.Lock();self.attempts=defaultdict(deque)
  with self.db() as c:
   c.executescript("""
   PRAGMA journal_mode=WAL;
   CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,name TEXT NOT NULL,email TEXT UNIQUE,salt TEXT,password TEXT,role TEXT NOT NULL DEFAULT 'player',suspended INTEGER NOT NULL DEFAULT 0);
   CREATE TABLE IF NOT EXISTS sessions(digest TEXT PRIMARY KEY,user TEXT REFERENCES users(id),expires REAL);
   CREATE TABLE IF NOT EXISTS identities(provider TEXT,subject TEXT,user TEXT REFERENCES users(id),PRIMARY KEY(provider,subject));
   CREATE TABLE IF NOT EXISTS progress(user TEXT PRIMARY KEY REFERENCES users(id),data TEXT NOT NULL);
   CREATE TABLE IF NOT EXISTS friendships(sender TEXT,recipient TEXT,status TEXT,PRIMARY KEY(sender,recipient));
   CREATE TABLE IF NOT EXISTS invites(id TEXT PRIMARY KEY,sender TEXT,recipient TEXT,code TEXT,expires REAL);
   CREATE TABLE IF NOT EXISTS content(kind TEXT,id TEXT,data TEXT,PRIMARY KEY(kind,id));
   CREATE TABLE IF NOT EXISTS audit(id INTEGER PRIMARY KEY,at REAL,actor TEXT,action TEXT,target TEXT);
   CREATE TRIGGER IF NOT EXISTS audit_no_update BEFORE UPDATE ON audit BEGIN SELECT RAISE(ABORT,'append-only audit'); END;
   CREATE TRIGGER IF NOT EXISTS audit_no_delete BEFORE DELETE ON audit BEGIN SELECT RAISE(ABORT,'append-only audit'); END;
   """)
 @contextlib.contextmanager
 def db(self):
  c=sqlite3.connect(self.path,timeout=10);c.row_factory=sqlite3.Row;c.execute("PRAGMA foreign_keys=ON")
  try:
   with c: yield c
  finally: c.close()
 def audit(self,c,actor,action,target=""):
  c.execute("INSERT INTO audit(at,actor,action,target) VALUES(?,?,?,?)",(time.time(),actor,action,target))
 def limit(self,identity):
  with self.lock:
   q=self.attempts[identity];now=time.monotonic()
   while q and now-q[0]>60:q.popleft()
   require(len(q)<20,"Too many requests; retry later",429);q.append(now)
 def session(self,c,user):
  token=secrets.token_urlsafe(32)
  c.execute("INSERT INTO sessions VALUES(?,?,?)",(hashlib.sha256(token.encode()).hexdigest(),user,time.time()+86400))
  return token
 def identity(self,c,token):
  require(isinstance(token,str) and 0<len(token)<256,"Authentication required",401)
  row=c.execute("SELECT u.* FROM users u JOIN sessions s ON u.id=s.user WHERE s.digest=? AND s.expires>?",(hashlib.sha256(token.encode()).hexdigest(),time.time())).fetchone()
  require(row is not None and not row['suspended'],"Authentication required",401);return row
 def public(self,u):return {k:u[k] for k in ('id','name','role')}|{'guest':u['email'] is None}
 def progress(self,c,user):
  row=c.execute("SELECT data FROM progress WHERE user=?",(user,)).fetchone();return json.loads(row[0]) if row else {}
 def call(self,method,path,body,token="",peer="local"):
  require(isinstance(body,dict))
  with self.db() as c:
   if path in ('/oauth/google/callback','/oauth/facebook/callback') or path.startswith('/oauth/'):
    raise Fault(503,'OAuth provider not configured; no identity accepted')
   if path=="/health" and method=="GET":return {'status':'ok','scope':'local/staging only'}
   if path in ('/auth/guest','/auth/register','/auth/login') and method=="POST":
    self.limit(peer)
    if path=="/auth/login":
     email=clean(body.get('email',''),254).casefold();p=body.get('password','')
     row=c.execute("SELECT * FROM users WHERE email=?",(email,)).fetchone()
     salt=row['salt'] if row else '00'*16
     digest=password_hash(p,salt)
     require(row is not None and hmac.compare_digest(row['password'],digest) and not row['suspended'],"Invalid credentials",401)
     uid=row['id']
    else:
     uid=secrets.token_hex(16);name=clean(body.get('name','Guest'))
     email=salt=digest=None
     if path=="/auth/register":
      email=clean(body.get('email',''),254).casefold();require(re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+',email) is not None)
      salt=secrets.token_hex(16);digest=password_hash(body.get('password',''),salt)
      require(c.execute("SELECT 1 FROM users WHERE email=?",(email,)).fetchone() is None,"Account cannot be created",409)
     c.execute("INSERT INTO users(id,name,email,salt,password) VALUES(?,?,?,?,?)",(uid,name,email,salt,digest))
    session=self.session(c,uid);self.audit(c,uid,path)
    return {'token':session,'user':self.public(c.execute("SELECT * FROM users WHERE id=?",(uid,)).fetchone())}
   user=self.identity(c,token);uid=user['id'];self.limit(uid)
   if path=="/me" and method=="GET":return {'user':self.public(user),'progress':self.progress(c,uid)}
   if path=="/auth/logout" and method=="POST":
    c.execute("DELETE FROM sessions WHERE digest=?",(hashlib.sha256(token.encode()).hexdigest(),));self.audit(c,uid,'logout');return {'ok':True}
   if path=="/auth/link-guest" and method=="POST":
    require(user['email'] is not None,"Sign into the destination account first")
    guest=self.identity(c,body.get('guest_token',''));require(guest['email'] is None and guest['id']!=uid)
    merged=self.progress(c,uid)
    for k,v in self.progress(c,guest['id']).items():merged[k]=max(merged.get(k,0),v)
    c.execute("INSERT OR REPLACE INTO progress VALUES(?,?)",(uid,json.dumps(merged)))
    c.execute("DELETE FROM sessions WHERE user=?",(guest['id'],));self.audit(c,uid,'link-guest',guest['id']);return {'ok':True,'progress':merged}
   if path=="/progress" and method=="POST":
    stats=body.get('progress');require(isinstance(stats,dict) and set(stats)<= {'xp','wins','matches','picture_wins'})
    require(all(type(v) is int and 0<=v<=100000000 for v in stats.values()))
    data=self.progress(c,uid)
    for k,v in stats.items():data[k]=max(v,data.get(k,0))
    c.execute("INSERT OR REPLACE INTO progress VALUES(?,?)",(uid,json.dumps(data)));self.audit(c,uid,'progress');return {'progress':data,'trust':'client-reported; not ranked'}
   if path.startswith('/friends') or path.startswith('/invites'):
    require(user['email'] is not None,"A registered account is required",403)
    if path=='/friends' and method=='GET':
     rows=c.execute("SELECT sender,recipient,status FROM friendships WHERE sender=? OR recipient=?",(uid,uid)).fetchall();return {'friends':[dict(x) for x in rows]}
    if path=='/friends/request' and method=='POST':
     target=clean(body.get('user_id',''));require(target!=uid and c.execute("SELECT 1 FROM users WHERE id=? AND email IS NOT NULL AND suspended=0",(target,)).fetchone() is not None)
     require(c.execute("SELECT 1 FROM friendships WHERE (sender=? AND recipient=?) OR (sender=? AND recipient=?)",(uid,target,target,uid)).fetchone() is None,"Request already exists",409)
     c.execute("INSERT INTO friendships VALUES(?,?,'pending')",(uid,target));self.audit(c,uid,'friend-request',target);return {'ok':True}
    if path=='/friends/accept' and method=='POST':
     target=clean(body.get('user_id',''));q=c.execute("UPDATE friendships SET status='accepted' WHERE sender=? AND recipient=? AND status='pending'",(target,uid));require(q.rowcount==1,"No request",404)
     self.audit(c,uid,'friend-accept',target);return {'ok':True}
    if path=='/invites' and method=='GET':
     return {'invites':[dict(x) for x in c.execute("SELECT id,sender,code,expires FROM invites WHERE recipient=? AND expires>?",(uid,time.time()))]}
    if path=='/invites' and method=='POST':
     target=clean(body.get('user_id',''));code=clean(body.get('code',''),12).upper();require(re.fullmatch('[A-Z0-9]{4,12}',code) is not None)
     require(c.execute("SELECT 1 FROM friendships WHERE status='accepted' AND ((sender=? AND recipient=?) OR (sender=? AND recipient=?))",(uid,target,target,uid)).fetchone() is not None,"Friendship required",403)
     c.execute("INSERT INTO invites VALUES(?,?,?,?,?)",(secrets.token_hex(12),uid,target,code,time.time()+3600));self.audit(c,uid,'room-invite',target);return {'ok':True,'room_verification':'not verified by room server'}
   if path.startswith('/admin/'):
    require(user['role']=='super_admin',"Administrator authorization required",403)
    if path=='/admin/photos' and method=='GET':
     catalog=json.loads((Path(__file__).resolve().parents[2]/'data/guess_picture_302/catalog.json').read_text(encoding='utf-8'))
     return {'photos':[x for x in catalog['items'] if x['group']=='original_200']}
    if path=='/admin/status'  and method=='GET':
     return {'scope':'this local service only','uptime_seconds':int(time.time()-self.started),'users':c.execute("SELECT count(*) FROM users").fetchone()[0],'events':c.execute("SELECT count(*) FROM audit").fetchone()[0],'production_servers':'not queried; unchanged'}
    if path=='/admin/audit' and method=='GET':return {'audit':[dict(x) for x in c.execute("SELECT * FROM audit ORDER BY id DESC LIMIT 100")]}
    if path=='/admin/players' and method=='GET':return {'players':[dict(x) for x in c.execute("SELECT id,name,role,suspended FROM users LIMIT 200")]}
    if path=='/admin/players' and method=='POST':
     target=clean(body.get('id',''));require(type(body.get('suspended')) is bool);require(target!=uid,"Cannot suspend own administrator")
     q=c.execute("UPDATE users SET suspended=? WHERE id=?",(int(body['suspended']),target));require(q.rowcount==1,"Unknown player",404)
     if body['suspended']:c.execute("DELETE FROM sessions WHERE user=?",(target,))
     self.audit(c,uid,'moderate-player',target);return {'ok':True}
    if path=='/admin/content' and method=='GET':return {'content':[dict(x) for x in c.execute("SELECT * FROM content LIMIT 1000")]}
    if path=='/admin/content' and method=='POST':
     kind=body.get('kind');key=clean(body.get('id',''));data=body.get('data');require(kind in ('photo','category','question','settings') and isinstance(data,dict))
     require(len(json.dumps(data))<16000)
     if kind in ('photo','category','question'):
      require(isinstance(data.get('labels'),dict) and all(isinstance(data['labels'].get(l),str) and data['labels'][l].strip() for l in ('ar','en','tr')),"Arabic, English and Turkish labels required")
     if kind=='photo':
      catalog=json.loads((Path(__file__).resolve().parents[2]/'data/guess_picture_302/catalog.json').read_text(encoding='utf-8'))
      require(data.get('asset') in {x['image'] for x in catalog['items'] if x['group']=='original_200'},"Only original catalog assets allowed")
     if kind=='question':
      opts=data.get('options');require(isinstance(opts,list) and len(opts)>=2 and all(isinstance(v,dict) and isinstance(v.get('id'),str) for v in opts))
      require(len({v['id'] for v in opts})==len(opts) and sum(v['id']==data.get('correct') for v in opts)==1,"Exactly one correct option required")
      for lang in ('ar','en','tr'):
       require(all(isinstance(v.get(lang),str) and v[lang].strip() for v in opts));require(len({v[lang].strip().casefold() for v in opts})==len(opts),"Duplicate localized options")
      aliases=data.get('aliases');require(isinstance(aliases,dict),'Accepted answer aliases required')
      correct=next(v for v in opts if v['id']==data['correct'])
      for lang in ('ar','en','tr'):
       values=aliases.get(lang);require(isinstance(values,list) and 0<len(values)<=20 and all(isinstance(v,str) and 0<len(v.strip())<=120 for v in values))
       normalized=[v.strip().casefold() for v in values]
       require(len(set(normalized))==len(normalized) and correct[lang].strip().casefold() in normalized,'Correct answer must be accepted once')
       require(not any(v[lang].strip().casefold() in normalized for v in opts if v['id']!=data['correct']),'Alias collides with distractor')
     if kind=='settings':
      require(set(data)<= {'turn_time','winning_points','capacity'} and bool(data))
      require(all(type(v) is int for v in data.values()))
      require(data.get('turn_time',30) in (0,10,20,30,60) and 1<=data.get('winning_points',10)<=50 and 2<=data.get('capacity',2)<=6,'Invalid game settings')
     c.execute("INSERT OR REPLACE INTO content VALUES(?,?,?)",(kind,key,json.dumps(data,ensure_ascii=False)));self.audit(c,uid,'draft-'+kind,key);return {'ok':True,'state':'draft only; does not modify game catalog or production'}
   raise Fault(404,'Unknown endpoint')

class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass # No passwords, bearer tokens or response bodies in access logs.
 def do_GET(self):self.handle_request('GET')
 def do_POST(self):self.handle_request('POST')
 def handle_request(self,method):
  try:
   expected=f'127.0.0.1:{self.server.server_port}'
   require(self.headers.get('Host')==expected,'Invalid host',403)
   origin=self.headers.get('Origin');require(origin in (None,'http://'+expected),'Invalid origin',403)
   if method=='GET' and self.path=='/brand.png':
    return self.respond(200,(Path(__file__).resolve().parents[2]/'assets/ui/gaming_hub_brand.png').read_bytes(),'image/png')
   if method=='GET' and self.path in ('/','/admin.js','/style.css'):
    name={'/':'index.html','/admin.js':'admin.js','/style.css':'style.css'}[self.path]
    raw=(Path(__file__).parent/'web'/name).read_bytes();return self.respond(200,raw,{'index.html':'text/html; charset=utf-8','admin.js':'text/javascript','style.css':'text/css'}[name])
   if method=='GET' and self.path.startswith('/asset/'):
    from http.cookies import SimpleCookie
    cookies=SimpleCookie(self.headers.get('Cookie',''));token=cookies['gh_session'].value if 'gh_session' in cookies else self.headers.get('Authorization','').removeprefix('Bearer ')
    with self.server.store.db() as c:
     user=self.server.store.identity(c,token);require(user['role']=='super_admin','Administrator authorization required',403)
    catalog=json.loads((Path(__file__).resolve().parents[2]/'data/guess_picture_302/catalog.json').read_text(encoding='utf-8'))
    item=next((x for x in catalog['items'] if x['group']=='original_200' and '/asset/'+x['id']==self.path),None)
    require(item is not None,'Unknown asset',404)
    return self.respond(200,(Path(__file__).resolve().parents[2]/item['image'].removeprefix('res://')).read_bytes(),'image/webp')
   body={}
   if method=='POST':
    require(self.headers.get('Content-Type','').split(';')[0]=='application/json','JSON required',415)
    length=int(self.headers.get('Content-Length','0'));require(0<length<=32768,'Body too large',413);body=json.loads(self.rfile.read(length))
   token=self.headers.get('Authorization','').removeprefix('Bearer ')
   if not token:
    from http.cookies import SimpleCookie
    cookies=SimpleCookie(self.headers.get('Cookie',''));token=cookies['gh_session'].value if 'gh_session' in cookies else ''
   result=self.server.store.call(method,self.path,body,token,self.client_address[0])
   cookie=None
   if 'token' in result:cookie='gh_session='+result['token']+'; HttpOnly; SameSite=Strict; Path=/; Max-Age=86400'
   if self.path=='/auth/logout':cookie='gh_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0'
   self.respond(200,json.dumps(result,ensure_ascii=False).encode(),'application/json; charset=utf-8',cookie)
  except Fault as e:self.respond(e.status,json.dumps({'error':e.message}).encode())
  except (ValueError,TypeError,KeyError):self.respond(400,b'{"error":"Invalid request"}')
  except Exception:self.respond(500,b'{"error":"Internal error"}')
 def respond(self,status,raw,content='application/json',cookie=None):
  self.send_response(status);self.send_header('Content-Type',content);self.send_header('Content-Length',str(len(raw)))
  self.send_header('Cache-Control','no-store');self.send_header('X-Content-Type-Options','nosniff');self.send_header('Referrer-Policy','no-referrer')
  self.send_header('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
  if cookie:self.send_header('Set-Cookie',cookie)
  self.end_headers();self.wfile.write(raw)

def make_server(db,port=8879):
 server=ThreadingHTTPServer(('127.0.0.1',port),Handler);server.store=Store(db);return server
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--db',required=True);parser.add_argument('--port',type=int,default=8879)
 parser.add_argument('--grant-first-super-admin');parser.add_argument('--confirm-first-admin',action='store_true');args=parser.parse_args()
 if args.grant_first_super_admin:
  require(args.confirm_first_admin,'Explicit --confirm-first-admin required')
  store=Store(args.db)
  with store.db() as c:
   c.execute('BEGIN IMMEDIATE')
   require(c.execute("SELECT 1 FROM users WHERE role='super_admin'").fetchone() is None,'An administrator already exists; offline recovery requires separate authorization')
   target=c.execute("SELECT * FROM users WHERE id=? AND email IS NOT NULL AND suspended=0",(args.grant_first_super_admin,)).fetchone()
   require(target is not None,'Existing registered account required')
   c.execute("UPDATE users SET role='super_admin' WHERE id=?",(target['id'],))
   store.audit(c,'local-operator','grant-first-super-admin',target['id'])
  print('First administrator assigned locally; no credentials printed or created.')
 else: make_server(args.db,args.port).serve_forever()
