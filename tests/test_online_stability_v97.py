import pathlib, unittest
P = pathlib.Path(__file__).resolve().parents[1] / "scripts/multiplayer.gd"
class TestOnlineStabilityV97(unittest.TestCase):
    def test_process_packets_before_timeout(self):
        text = P.read_text()
        block = text.split("if state == WebSocketPeer.STATE_OPEN:", 1)[1]
        self.assertLess(block.index("early_packet"), block.index("if ping_waiting and now_ms"))
    def test_mobile_pong_grace(self):
        self.assertIn("const PONG_TIMEOUT_MS: int = 25000", P.read_text())
    def test_old_server_diagnostic(self):
        self.assertIn("Server update required for match recovery", P.read_text())
if __name__ == "__main__": unittest.main()
