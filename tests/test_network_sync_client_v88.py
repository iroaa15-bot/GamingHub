"""Static Godot contract checks; native Godot testing still required."""
import unittest
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / 'scripts' / 'multiplayer.gd').read_text()
server = (Path(__file__).resolve().parents[1] / 'server' / 'server.py').read_text()

class NetworkSyncClientV88(unittest.TestCase):
    def test_sync_on_move_timeout(self):
        self.assertIn('if action_in_flight and not sync_pending', source)
        self.assertIn('_send({"type":"sync"})', source)
    def test_no_move_resend(self):
        self.assertNotIn('_send({"type":"ask"})', source)
        self.assertNotIn('_send({"type":"guess"})', source)
    def test_sync_timeout_reconnect(self):
        self.assertIn('SYNC_TIMEOUT_MS', source)
        self.assertIn('if sync_pending and now_ms - sync_started_ms > SYNC_TIMEOUT_MS:', source)
    def test_ping_liveness(self):
        self.assertIn('PING_INTERVAL_MS', source)
        self.assertIn('PONG_TIMEOUT_MS', source)
        self.assertIn('"pong":', source)
    def test_sync_preserves_rotating_resume_token(self):
        self.assertIn('started_message["resume_token"] = resume_token', source)
    def test_server_owns_sync_authentication(self):
        self.assertIn('code = connections.get(ws)', server)
        self.assertIn('ws not in room.players', server)

if __name__ == '__main__': unittest.main()
