import sys,asyncio,unittest,time,secrets,base64
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from secure_agreement_local import SecureAgreementHub
from photo_duel_extension import ProtocolError
class Peer:
 async def send(self,value):pass
class Security(unittest.IsolatedAsyncioTestCase):
 async def test_membership_boundaries(self):
  h=SecureAgreementHub(secrets.token_urlsafe(48),':memory:');a,b,stranger=Peer(),Peer(),Peer()
  async def act(peer,kind,**fields):return await h.handle(peer,dict(type=kind,protocol=3,**fields))
  try:
   with self.assertRaises(ProtocolError):await act(stranger,'duel_create',players=2)
   for peer in [a,b]:h.identities[peer]=h.sessions.issue()[1]
   await act(a,'duel_create',players=2,target=1,room_agreement=True,picture_difficulty='easy')
   room,_=h.binding(a);await act(b,'duel_join',code=room.code)
   await act(a,'duel_propose',picture_category='animals',primary_mode='voice')
   for peer in [a,b]:await act(peer,'duel_voice_state',enabled=True)
   epoch=h.voice[room.code]['epoch'];pcm=base64.b64encode(bytes(640)).decode()
   with self.assertRaises(ProtocolError):await act(stranger,'duel_voice_audio',epoch=epoch,seq=1,pcm=pcm)
   await act(a,'duel_voice_audio',epoch=epoch,seq=1,pcm=pcm)
   with self.assertRaises(ProtocolError):await act(a,'duel_voice_audio',epoch=epoch,seq=1,pcm=pcm)
   with self.assertRaises(ProtocolError):await act(a,'duel_voice_audio',epoch=epoch-1,seq=2,pcm=pcm)
   await act(a,'duel_propose',picture_category='animals',primary_mode='tap')
   self.assertFalse(any(h.voice[room.code]['enabled']))
   with self.assertRaises(ProtocolError):await act(a,'duel_voice_state',enabled=True)
   await act(a,'duel_propose',picture_category='animals',primary_mode='voice')
   for peer in [a,b]:await act(peer,'duel_accept',config_revision=room.config_revision,picture_difficulty='easy')
   await act(a,'duel_start');await act(a,'duel_guess',guess='fixture');await act(b,'duel_confirm',correct=True)
   self.assertTrue(room.match_finished);self.assertFalse(room.closed);self.assertIsNone(room.deadline)
   self.assertTrue(h.voice_state(room,0)['available'])
   with self.assertRaises(ProtocolError):await act(a,'duel_guess',guess='another')
   await act(a,'duel_voice_state',enabled=True)
   with self.assertRaises(ProtocolError):await act(a,'duel_session_refresh',token=h.sessions.issue()[0])
   # Presence refresh replaces game-idle expiry for connected agreed rooms only.
   room.activity=time.monotonic()-1300
   presence=asyncio.create_task(h._membership_presence());await asyncio.sleep(5.05);presence.cancel();await asyncio.gather(presence,return_exceptions=True)
   self.assertLess(time.monotonic()-room.activity,1)
   await h.disconnect(b)
   self.assertFalse(h.voice_state(room,0)['available']);self.assertFalse(any(h.voice[room.code]['enabled']))
   await act(a,'duel_leave');self.assertNotIn(room.code,h.rooms)
  finally:h.moderation.db.close()
if __name__=='__main__':unittest.main()
