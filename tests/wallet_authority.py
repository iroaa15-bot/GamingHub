import sys,tempfile,unittest,sqlite3,concurrent.futures
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'services/player_portal'))
from service import Store,Fault
from wallet import WalletError,DEFAULTS
class Authority(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.store=Store(str(Path(self.tmp.name)/'wallet.sqlite'))
  self.guest=self.store.call('POST','/auth/guest',{'name':'Wallet fixture'},'','test-peer')
  self.uid=self.guest['user']['id'];self.token=self.guest['token'];self.wallet=self.store.wallet
 def tearDown(self):self.tmp.cleanup()
 def verify(self,event):return {'owner':self.uid,'transaction_id':event,'test':False}
 def credit(self,event):
  with self.store.db() as c:return self.wallet.verified_reward(c,self.uid,event,self.verify)
 def test_authoritative_credit_and_atomic_spend(self):
  self.assertEqual(self.store.call('GET','/wallet',{},self.token)['balance'],0)
  for path in ['/wallet/reward','/wallet/spend','/ads/ssv']:
   with self.assertRaises(Fault) as e:self.store.call('POST',path,{'verified':True,'amount':99999},self.token)
   self.assertEqual(e.exception.status,503)
  self.credit('fixture-ssv-1');self.credit('fixture-ssv-1')
  with self.store.db() as c:
   self.assertEqual(self.wallet.balance(c,self.uid),20)
   with self.assertRaises(WalletError):self.wallet.verified_reward(c,self.uid,'bad',lambda e:{'owner':self.uid,'transaction_id':e,'test':True})
  self.credit('fixture-ssv-2')
  def spend(_):
   with self.store.db() as c:return self.wallet.spend(c,self.uid,'same-request','hint',{'round':'fixture'},lambda *args:{'authorized':True,'hint':'fixture only'})
  with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(spend,range(4)))
  self.assertTrue(all(r==results[0] for r in results))
  with self.store.db() as c:
   self.assertEqual(self.wallet.balance(c,self.uid),20)
   with self.assertRaises(WalletError):self.wallet.spend(c,self.uid,'same-request','letter',{'round':'different'},lambda *a:{'authorized':True})
   with self.assertRaises(WalletError):self.wallet.spend(c,self.uid,'unauthorized','hint',{},lambda *a:{'authorized':False})
   self.assertEqual(self.wallet.balance(c,self.uid),20)
   with self.assertRaises(sqlite3.IntegrityError):c.execute('DELETE FROM wallet_events')
 def test_guest_link_and_admin_policy(self):
  self.credit('fixture-link')
  account=self.store.call('POST','/auth/register',{'name':'Account fixture','email':'wallet@example.test','password':'fixture-password-only'},'','test-peer')
  with self.assertRaises(Fault) as e:self.store.call('POST','/admin/economy',{'prices':DEFAULTS},account['token'])
  self.assertEqual(e.exception.status,403)
  result=self.store.call('POST','/auth/link-guest',{'guest_token':self.token},account['token'])
  self.assertTrue(result['ok'])
  self.assertEqual(self.store.call('GET','/wallet',{},account['token'])['balance'],20)
  self.credit('fixture-link')
  self.assertEqual(self.store.call('GET','/wallet',{},account['token'])['balance'],20)
  with self.assertRaises(Fault):self.store.call('GET','/wallet',{},self.token)
if __name__=='__main__':unittest.main()
