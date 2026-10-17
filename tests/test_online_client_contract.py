"""Static regression tests for client-side multiplayer lifecycle."""
import unittest
from pathlib import Path
SOURCE=(Path(__file__).resolve().parents[1]/"scripts/multiplayer.gd").read_text()
class OnlineClientContract(unittest.TestCase):
 def test_reconnect_resets_state(self):
  self.assertIn("pending_action = queued_action",SOURCE)
 def test_disconnect_resets_state(self):
  self.assertIn('elif state == WebSocketPeer.STATE_CLOSED and (connected or connect_started_ms > 0):',SOURCE)
  self.assertIn('   _reset_match_state()\n   pending_action.clear()',SOURCE)
  self.assertIn('   _start_reconnect()', SOURCE)
 def test_validates_address(self):
  self.assertIn('url.begins_with("wss://")',SOURCE)
  self.assertIn('url.begins_with("ws://")',SOURCE)
 def test_room_exit_clears_state(self):
  self.assertIn('"disconnected":\n   _reset_voice()\n   _reset_match_state()',SOURCE)
if __name__=="__main__": unittest.main()
