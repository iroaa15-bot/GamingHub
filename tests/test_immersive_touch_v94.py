import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class ImmersiveTouch(unittest.TestCase):
 def test_native_lightweight_backdrop(self):
  skin=(ROOT/'scripts/visual_skin.gd').read_text()
  self.assertIn('extends Control',skin)
  self.assertIn('func _draw()',skin)
  self.assertIn('mouse_filter = Control.MOUSE_FILTER_IGNORE',skin)
  self.assertNotIn('ShaderMaterial',skin)
  self.assertIn('func add_hero(',skin)
 def test_consistent_scenes(self):
  for name in ('main','multiplayer'):
   source=(ROOT/f'scripts/{name}.gd').read_text()
   self.assertIn('preload("res://scripts/visual_skin.gd")',source)
   self.assertIn('VisualSkin.new()',source)
   self.assertIn('VisualSkin.add_hero(',source)
   self.assertIn('VisualSkin.decorate_button(',source)
 def test_tactile_accessibility(self):
  source=(ROOT/'scripts/main.gd').read_text()
  self.assertIn('haptics_enabled',source)
  self.assertIn('Input.vibrate_handheld(14)',source)
  self.assertIn('if reduced_motion:',source)
  self.assertIn('play_tap()',source)
 def test_tap_asset_and_permissions(self):
  import wave
  with wave.open(str(ROOT/'assets/audio/ui_tap.wav'),'rb') as w:
   self.assertEqual(w.getnchannels(),1)
   self.assertLess(w.getnframes()/w.getframerate(),0.1)
  self.assertEqual((ROOT/'export_presets.cfg').read_text().count('permissions/vibrate=true'),2)
 def test_online_input_theme(self):
  source=(ROOT/'scripts/multiplayer.gd').read_text()
  self.assertIn('VisualSkin.decorate_input(i)',source)
  self.assertIn('button.button_down.connect',source)
  self.assertIn('reduced_motion',source)
  self.assertIn('Input.vibrate_handheld(12)',source)
 def test_identity_untouched(self):
  self.assertTrue((ROOT/'assets/ui/gaming_hub_icon.png').exists())
