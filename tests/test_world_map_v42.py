import pathlib, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
CODE = (ROOT / "scripts/main.gd").read_text()
class WorldMapTests(unittest.TestCase):
 def test_stage_grid(self):
  self.assertIn("grid.columns = 3", CODE)
  self.assertIn("journey_stage_tile(stage, unlocked)", CODE)
 def test_locked_tiles(self):
  self.assertIn("tile.disabled = not accessible", CODE)
 def test_unlock_threshold(self):
  self.assertIn("correct_count * 100 >= attempted * 60", CODE)
 def test_no_old_stage_skip(self):
  self.assertIn('selected_stage == frontier', CODE)
 def test_progress(self):
  self.assertIn("progress.value = unlocked", CODE)
if __name__ == "__main__": unittest.main()
