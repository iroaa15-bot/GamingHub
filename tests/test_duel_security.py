import secrets,sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"server"))
from duel_security import Sessions,Limits,Moderation
class SecurityTests(unittest.TestCase):
 def test_signed_session_and_tamper_rejection(self):
  issuer=Sessions(secrets.token_urlsafe(48));token,claims=issuer.issue()
  self.assertEqual(issuer.verify(token)["sub"],claims["sub"])
  altered=("A" if token[0]!="A" else "B")+token[1:]
  with self.assertRaises(ValueError):issuer.verify(altered)
  with self.assertRaises(ValueError):Sessions(secrets.token_urlsafe(48)).verify(token)
 def test_expiry_and_short_secret(self):
  issuer=Sessions(secrets.token_urlsafe(48),ttl=-1);token,_=issuer.issue()
  with self.assertRaises(ValueError):issuer.verify(token)
  with self.assertRaises(ValueError):Sessions("short")
 def test_rate_limit_is_enforced(self):
  limiter=Limits();self.assertTrue(limiter.admit("a",2,60));self.assertTrue(limiter.admit("a",2,60));self.assertFalse(limiter.admit("a",2,60));self.assertTrue(limiter.admit("b",2,60))
 def test_report_and_block_persistence(self):
  with tempfile.TemporaryDirectory() as folder:
   path=str(Path(folder)/"moderation.sqlite");store=Moderation(path)
   store.block("a","b");identifier=store.report("a","b","test report")
   self.assertTrue(store.blocked("b","a"));store.db.close()
   restored=Moderation(path);self.assertTrue(restored.blocked("a","b"));self.assertEqual(restored.db.execute("SELECT id FROM reports").fetchone()[0],identifier);restored.db.close()
if __name__=="__main__":unittest.main()
