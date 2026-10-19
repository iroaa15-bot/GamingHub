"""Static regression checks for gameplay reconnect invariants.
Run with: python -m unittest discover -s tests -p 'test_connection_contract.py'
"""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

class ConnectionContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = (ROOT / 'scripts/multiplayer.gd').read_text(encoding='utf-8')
        cls.server = (ROOT / 'server/server.py').read_text(encoding='utf-8')

    def test_reconnect_pins_original_endpoint(self):
        self.assertIn('server_url = url', self.client)
        self.assertGreaterEqual(self.client.count('socket.connect_to_url(server_url)'), 2)
        self.assertNotIn('socket.connect_to_url(address_input.text.strip_edges())', self.client)

    def test_server_rotates_resume_token(self):
        self.assertIn('room.resume_tokens[idx] = secrets.token_hex(32)', self.server)
        self.assertIn('secrets.compare_digest(expected, token)', self.server)

    def test_client_replays_snapshot_not_move(self):
        self.assertIn('_send({"type":"sync"})', self.client)
        self.assertIn('started_message["resume_token"] = resume_token', self.client)
        self.assertIn('"type":"resume", "code":room_code, "token":resume_token', self.client)

    def test_voice_requires_both_peers(self):
        self.assertIn('if not all(room.voice_enabled):', self.server)

if __name__ == '__main__':
    unittest.main()
