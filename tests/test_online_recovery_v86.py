"""Source-level regression checks: Godot must still be run for runtime validation."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'scripts/multiplayer.gd').read_text(encoding='utf-8')
class OnlineRecoveryV86(unittest.TestCase):
 def test_lobby_pending_blocks_double_room_requests(self):
  self.assertIn('or lobby_request_pending or leaving:', S)
  self.assertIn('lobby_request_pending = true', S)
  self.assertIn('"room", "queue", "started", "error", "left", "disconnected"', S)
 def test_cancel_ignores_stale_room_start(self):
  self.assertIn('if leaving and kind not in ["left", "disconnected"]:', S)
  self.assertIn('_send({"type":"leave"})', S)
  self.assertIn('leave_started_ms = Time.get_ticks_msec()', S)
 def test_move_timeout_never_auto_retries(self):
  self.assertIn('move_started_ms = Time.get_ticks_msec()', S)
  self.assertIn('now_ms - move_started_ms > SERVER_REPLY_TIMEOUT_MS', S)
  self.assertIn('socket.close()', S)
  self.assertIn('Never resend it', S)
  self.assertNotIn('_send(last_move)', S)
 def test_socket_replaced_on_cancellation_and_failure(self):
  self.assertGreaterEqual(S.count('socket = WebSocketPeer.new()'), 4)
  self.assertIn('Match restored successfully', S)
 def test_visible_deduction_while_waiting(self):
  self.assertIn('func _update_deduction_status()', S)
  self.assertIn('Remaining possibilities: %d', S)
  self.assertIn('if int(msg.get("player", -1)) == player_index:', S)
 def test_all_timeouts_have_user_message(self):
  for text in ('Room request timed out','Checking move status with server','Match sync failed','Leave acknowledgement timed out','Connection timed out'):
   self.assertIn(text,S)
if __name__=='__main__': unittest.main()
