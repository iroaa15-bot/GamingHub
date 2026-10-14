"""Static source contracts; runtime Godot validation remains separate."""
from pathlib import Path
import unittest
SRC=(Path(__file__).resolve().parents[1]/'scripts/multiplayer.gd').read_text()

class ReconnectClientContract(unittest.TestCase):
    def test_uses_rotating_server_token(self):
        self.assertIn('resume_token = str(msg.get("resume_token", ""))', SRC)
        self.assertIn('"type":"resume", "code":room_code, "token":resume_token', SRC)
        self.assertNotIn('store_string(resume_token)', SRC)
    def test_restores_server_events_without_resending_move(self):
        self.assertIn('var replay: Array = msg.get("history", [])', SRC)
        self.assertIn('"question", "guess", "finished"', SRC)
        self.assertNotIn('_send(last_move)', SRC)
    def test_pauses_actions_and_expires_attempt(self):
        self.assertIn('or reconnecting or opponent_paused:', SRC)
        self.assertIn('reconnect_now >= reconnect_deadline_ms:', SRC)
        self.assertIn('"paused":', SRC)
        self.assertIn('"peer_resumed":', SRC)
    def test_cancel_clears_session(self):
        self.assertIn('if reconnecting:\n  socket.close()', SRC)
        self.assertIn('resume_token = ""', SRC)

if __name__=='__main__': unittest.main()
