import tempfile,unittest
from pathlib import Path
from federation import Federation,VerifiedIdentity
from service import Store,Fault
class FederationBoundary(unittest.TestCase):
 def test_disabled_and_conflicting_identity(self):
  with tempfile.TemporaryDirectory() as td:
   store=Store(str(Path(td)/'federation.sqlite'))
   with store.db() as c:
    for uid in ('a','b'):c.execute("INSERT INTO users(id,name,email) VALUES(?,?,?)",(uid,uid,uid+'@example.test'))
    a=store.session(c,'a');b=store.session(c,'b')
   with self.assertRaises(Fault):Federation().link(store,a,'google','code','callback','nonce','pkce')
   class TestOnlyVerifier:
    def exchange_and_verify(self,*args):return VerifiedIdentity('google','test-subject')
   federation=Federation({'google':TestOnlyVerifier()})
   self.assertTrue(federation.link(store,a,'google','code','callback','nonce','pkce')['ok'])
   with self.assertRaises(Fault):federation.link(store,b,'google','code','callback','nonce','pkce')
   print('PASS: federation boundary disabled by default and rejects cross-account link; test verifier only, NOT Google authentication')
if __name__=='__main__':unittest.main()
