"""Federation boundary. No client-asserted identity or email-only account linking.
Provider verifiers must be implemented with approved official SDKs/configuration.
No verifier is enabled by default; no network tokens are logged or persisted.
"""
from dataclasses import dataclass
from typing import Protocol
from service import Fault,require

@dataclass(frozen=True)
class VerifiedIdentity:
 provider: str
 subject: str

class IdentityVerifier(Protocol):
 def exchange_and_verify(self,code: str,redirect_uri: str,nonce: str,pkce_verifier: str) -> VerifiedIdentity: ...

class Federation:
 def __init__(self,verifiers=None):self.verifiers=dict(verifiers or {})
 def link(self,store,account_token,provider,code,redirect_uri,nonce,pkce_verifier):
  require(provider in ('google','facebook'))
  verifier=self.verifiers.get(provider)
  if verifier is None:raise Fault(503,'Provider SDK and credentials not configured')
  identity=verifier.exchange_and_verify(code,redirect_uri,nonce,pkce_verifier)
  require(isinstance(identity,VerifiedIdentity) and identity.provider==provider and 0<len(identity.subject)<=255,'Unverified identity',401)
  with store.db() as c:
   c.execute('BEGIN IMMEDIATE')
   user=store.identity(c,account_token)
   require(user['email'] is not None,'Sign into the destination account first',403)
   existing=c.execute('SELECT user FROM identities WHERE provider=? AND subject=?',(provider,identity.subject)).fetchone()
   require(existing is None or existing['user']==user['id'],'Identity already linked to another account',409)
   c.execute('INSERT OR IGNORE INTO identities VALUES(?,?,?)',(provider,identity.subject,user['id']))
   store.audit(c,user['id'],'link-'+provider,identity.subject)
   return {'ok':True}
