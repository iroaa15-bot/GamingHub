import sys,asyncio,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from photo_duel_agreement_local import AgreementHub
from photo_duel_extension import ProtocolError
class Peer:
 async def send(self,value):pass
class Security(unittest.IsolatedAsyncioTestCase):
 async def test_configuration_security(self):
  h=AgreementHub();host=Peer();other=Peer()
  async def action(peer,kind,**fields):return await h.handle(peer,dict(type=kind,protocol=3,**fields))
  with self.assertRaises(ProtocolError):await action(host,'duel_create',room_agreement=True,picture_difficulty='invented')
  self.assertEqual(len(h.rooms),0)
  await action(host,'duel_create',room_agreement=True,picture_difficulty='hard',players=2)
  r,idx=h.binding(host);code=r.code
  await action(host,'duel_accept',config_revision=r.config_revision,picture_difficulty='hard')
  await action(other,'duel_join',code=code)
  self.assertEqual(r.confirmed,[False,False])
  before=(r.config_revision,r.picture_category,r.catalog)
  with self.assertRaises(ProtocolError):await action(host,'duel_propose',picture_category='celebrities',primary_mode='tap')
  self.assertEqual((r.config_revision,r.picture_category,r.catalog),before)
  with self.assertRaises(ProtocolError):await action(host,'duel_propose',picture_category='science',primary_mode='tap')
  self.assertEqual((r.config_revision,r.picture_category,r.catalog),before)
  with self.assertRaises(ProtocolError):await action(host,'duel_accept',config_revision=1.0,picture_difficulty='hard')
  for peer in [host,other]:await action(peer,'duel_accept',config_revision=r.config_revision,picture_difficulty='hard')
  await action(host,'duel_start')
  # A hostile guest cannot change immutable difficulty/category/mode in an active game.
  with self.assertRaises(ProtocolError):await action(host,'duel_propose',picture_category='fruits',primary_mode='text',picture_difficulty='easy')
  self.assertEqual(r.picture_difficulty,'hard')
  # A completed guess still scores, draws a distinct replacement, and retains the agreed catalog.
  prior=r.images.copy();await action(host,'duel_guess',guess='test')
  await action(other,'duel_confirm',correct=True)
  self.assertEqual(r.scores,[1,0]);self.assertNotEqual(r.images[0],prior[0]);self.assertEqual(len(set(r.images)),2)
  self.assertEqual(r.picture_difficulty,'hard')
  self.assertTrue(all(h.filter_items[key]['difficulty']=='hard' for key in r.images))
  await h.disconnect(other)
  stranger=Peer()
  with self.assertRaises(ProtocolError):await action(stranger,'duel_resume',code=code,token='wrong')
  self.assertTrue(r.paused)
if __name__=='__main__':unittest.main()
