"""Authoritative local coin ledger. No client/native callback can mint spendable coins.
SSV and multiplayer hint authorization deliberately fail closed until configured.
"""
import hashlib,json,time
DEFAULTS={'reward':20,'hint':20,'letter':30,'remove_two':40,'replace_image':60}
class WalletError(ValueError):pass
class Wallet:
 def install(self,c):
  c.executescript("""
  CREATE TABLE IF NOT EXISTS wallet_balances(owner TEXT PRIMARY KEY REFERENCES users(id),coins INTEGER NOT NULL CHECK(coins>=0));
  CREATE TABLE IF NOT EXISTS wallet_aliases(guest TEXT PRIMARY KEY REFERENCES users(id),owner TEXT NOT NULL REFERENCES users(id));
  CREATE TABLE IF NOT EXISTS wallet_events(id TEXT PRIMARY KEY,owner TEXT NOT NULL,kind TEXT NOT NULL,delta INTEGER NOT NULL,balance INTEGER NOT NULL,request_hash TEXT NOT NULL,external_id TEXT UNIQUE,receipt TEXT NOT NULL,at REAL NOT NULL);
  CREATE TRIGGER IF NOT EXISTS wallet_no_update BEFORE UPDATE ON wallet_events BEGIN SELECT RAISE(ABORT,'append-only ledger'); END;
  CREATE TRIGGER IF NOT EXISTS wallet_no_delete BEFORE DELETE ON wallet_events BEGIN SELECT RAISE(ABORT,'append-only ledger'); END;
  CREATE TABLE IF NOT EXISTS wallet_settings(id INTEGER PRIMARY KEY CHECK(id=1),data TEXT NOT NULL);
  """)
 def settings(self,c):
  row=c.execute('SELECT data FROM wallet_settings WHERE id=1').fetchone()
  return json.loads(row[0]) if row else DEFAULTS.copy()
 def configure(self,c,values):
  if not isinstance(values,dict) or set(values)!=set(DEFAULTS) or not all(type(v) is int and 1<=v<=10000 for v in values.values()):raise WalletError('Invalid economy configuration')
  c.execute('INSERT OR REPLACE INTO wallet_settings VALUES(1,?)',(json.dumps(values),))
 def root(self,c,owner):
  seen=set()
  while owner not in seen:
   seen.add(owner);row=c.execute('SELECT owner FROM wallet_aliases WHERE guest=?',(owner,)).fetchone()
   if row is None:return owner
   owner=row[0]
  raise WalletError('Account link cycle')
 def balance(self,c,owner):
  row=c.execute('SELECT coins FROM wallet_balances WHERE owner=?',(self.root(c,owner),)).fetchone();return row[0] if row else 0
 def _lock(self,c):
  if not c.in_transaction:c.execute('BEGIN IMMEDIATE')
 def _event(self,c,key,owner,kind,delta,fingerprint,external_id=None,receipt=None):
  old=c.execute('SELECT request_hash,receipt FROM wallet_events WHERE id=?',(key,)).fetchone()
  if old:
   if old[0]!=fingerprint:raise WalletError('Idempotency key reused with different request')
   return json.loads(old[1])
  total=self.balance(c,owner)+delta
  if total<0:raise WalletError('Insufficient verified coins')
  result={'transaction':key,'balance':total,'effect':receipt}
  c.execute('INSERT INTO wallet_balances VALUES(?,?) ON CONFLICT(owner) DO UPDATE SET coins=excluded.coins',(owner,total))
  c.execute('INSERT INTO wallet_events VALUES(?,?,?,?,?,?,?,?,?)',(key,owner,kind,delta,total,fingerprint,external_id,json.dumps(result,ensure_ascii=False),time.time()))
  return result
 def verified_reward(self,c,owner,event_id,verify):
  # Trusted SSV adapter must verify the ORIGINAL signed query and return bound claims.
  # This callable has no HTTP route and is never supplied by a player or native callback.
  self._lock(c);claims=verify(event_id)
  if not isinstance(claims,dict) or claims.get('transaction_id')!=event_id or claims.get('owner')!=owner or claims.get('test') is not False:raise WalletError('Unverified reward')
  fingerprint=hashlib.sha256((owner+'|'+event_id).encode()).hexdigest();owner=self.root(c,owner);amount=self.settings(c)['reward']
  return self._event(c,'ssv:'+event_id,owner,'verified-ad',amount,fingerprint,event_id)
 def spend(self,c,owner,key,action,context,authorize):
  self._lock(c);owner=self.root(c,owner)
  if action not in ('hint','letter','remove_two','replace_image') or not isinstance(context,dict) or not isinstance(key,str) or not 8<=len(key)<=100:raise WalletError('Invalid spend request')
  fingerprint=hashlib.sha256(json.dumps([owner,action,context],sort_keys=True).encode()).hexdigest();key='spend:'+owner+':'+key
  old=c.execute('SELECT request_hash,receipt FROM wallet_events WHERE id=?',(key,)).fetchone()
  if old:
   if old[0]!=fingerprint:raise WalletError('Idempotency conflict')
   return json.loads(old[1])
  effect=authorize(owner,action,context)
  if not isinstance(effect,dict) or effect.get('authorized') is not True:raise WalletError('Hint authorization required')
  # Authorizer returns a pure bounded receipt; it must not mutate a remote game before commit.
  return self._event(c,key,owner,action,-self.settings(c)[action],fingerprint,receipt=effect)
 def link_guest(self,c,guest,owner):
  self._lock(c);owner=self.root(c,owner)
  old=c.execute('SELECT owner FROM wallet_aliases WHERE guest=?',(guest,)).fetchone()
  if old:
   if self.root(c,old[0])!=owner:raise WalletError('Guest already linked')
   return
  if guest==owner:raise WalletError('Invalid account link')
  amount=self.balance(c,guest);fp=hashlib.sha256((guest+'|'+owner).encode()).hexdigest()
  self._event(c,'link-out:'+guest,guest,'link-out',-amount,fp)
  self._event(c,'link-in:'+guest,owner,'link-in',amount,fp)
  c.execute('INSERT INTO wallet_aliases VALUES(?,?)',(guest,owner))
