import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
class RevealTests(unittest.TestCase):
 def test_grid_and_reveal(self):
  code = (ROOT/'scripts/main.gd').read_text()
  self.assertIn('cover.columns = columns', code)
  self.assertIn('for tile_index in range(tile_total)', code)
  self.assertIn('for step in range(reveal_step)', code)
 def test_hint_penalty(self):
  code = (ROOT/'scripts/main.gd').read_text()
  self.assertIn('hint_used = true', code)
  self.assertIn('(5 if hint_used else 0)', code)
 def test_brand_icon(self):
  self.assertTrue((ROOT/'assets/ui/gaming_hub_icon.png').exists())
if __name__ == '__main__': unittest.main()
