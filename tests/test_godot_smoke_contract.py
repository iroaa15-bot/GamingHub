import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class SmokeContract(unittest.TestCase):
 def test_scene_paths_exist(self):
  for name in ("Main","Multiplayer"):
   self.assertTrue((ROOT/"scenes"/(name+".tscn")).exists())
 def test_smoke_script_references_scenes(self):
  s=(ROOT/"tests/godot_smoke.gd").read_text()
  self.assertIn("res://scenes/Main.tscn",s)
  self.assertIn("res://scenes/Multiplayer.tscn",s)
  self.assertIn("quit(1)",s)
 def test_ci_runs_godot_smoke(self):
  s=(ROOT/".github/workflows/godot-checks.yml").read_text()
  self.assertIn("version: 4.5.1",s)
  self.assertIn("--script res://tests/godot_smoke.gd",s)
  self.assertIn("release/verify_archive_runtime.py",s)
