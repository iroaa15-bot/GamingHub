import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class FocusedRelease(unittest.TestCase):
 def test_no_3d_scenes(self):
  for p in ('scenes/Island3D.tscn','scenes/CharacterShowroom.tscn','assets/characters/meshy_animated_character.glb'):
   self.assertFalse((ROOT/p).exists(),p)
 def test_home_priority(self):
  s=(ROOT/'scripts/main.gd').read_text()
  self.assertIn('func start_guess_offline()',s)
  self.assertIn('func show_more_games()',s)
  self.assertNotIn('open_character_showroom',s)
  self.assertNotIn('start_island_3d',s)
 def test_multiplayer_backend_kept(self):
  self.assertTrue((ROOT/'scenes/Multiplayer.tscn').exists())
  self.assertTrue((ROOT/'server/server.py').exists())
