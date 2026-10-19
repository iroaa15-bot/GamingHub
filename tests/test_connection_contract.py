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

    def test_snapshot_preserves_question_languages(self):
        snapshot = self.server.split('def snapshot(', 1)[1].split('async def cleanup_room(', 1)[0]
        for language in ('questions', 'questions_ar', 'questions_tr'):
            self.assertIn(repr(language) + ':', snapshot)

    def test_snapshot_never_sends_own_secret_card(self):
        snapshot = self.server.split('def snapshot(', 1)[1].split('async def cleanup_room(', 1)[0]
        self.assertIn('public_card(room.cards[1-index])', snapshot)
        self.assertNotIn('public_card(room.cards[index])', snapshot)
        self.assertNotIn("'cards': room.cards", snapshot)

    def test_resume_resets_voice_consent(self):
        resume = self.server.split("if action == 'resume':", 1)[1].split('# Optional voice signaling only.', 1)[0]
        self.assertIn('room.voice_enabled = [False, False]', resume)
        self.assertIn("snapshot(room, idx, 'resumed', include_token=True)", resume)

    def test_resume_errors_are_scoped(self):
        resume = self.server.split("if action == 'resume':", 1)[1].split('# Optional voice signaling only.', 1)[0]
        self.assertEqual(resume.count("'scope':'resume'"), 6)
        self.assertIn('str(msg.get("scope", "")) == "resume"', self.client)

    def test_audio_is_not_counted_as_gameplay_rate(self):
        handler = self.server.split('async def handler(ws):', 1)[1].split('# Additive historical library.', 1)[0]
        self.assertIn("if action != 'voice_audio':", handler)
        self.assertIn("if len(raw) > 20000:", handler)
        self.assertIn("if len(recent) >= 80:", self.server)

    def test_voice_requires_both_peers(self):
        self.assertIn('if not all(room.voice_enabled):', self.server)

if __name__ == '__main__':
    unittest.main()
