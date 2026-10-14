from pathlib import Path
import unittest
S = (Path(__file__).resolve().parents[1]/"scripts/main.gd").read_text(encoding="utf-8")
class VisualMysteryTests(unittest.TestCase):
 def test_three_modes(self):
  self.assertIn("func visual_challenge_type()",S)
  self.assertIn("(question_index / 3) % 3",S)
  self.assertIn("5 if challenge == 1",S)
 def test_hint_penalty_and_progress(self):
  self.assertIn("hint_used = true",S)
  self.assertIn("VISIBLE TILES: %d / %d",S)
 def test_round_finish_blocks_reveal(self):
  self.assertIn("if round_finished or revealed[0] >= tile_total:",S)
if __name__ == "__main__": unittest.main()
