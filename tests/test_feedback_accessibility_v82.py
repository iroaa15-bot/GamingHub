"""v8.2 sound and accessibility contracts. Not a Godot runtime test."""
from pathlib import Path
import unittest
import wave

ROOT=Path(__file__).resolve().parents[1]
MAIN=(ROOT/'scripts/main.gd').read_text(encoding='utf-8')

class FeedbackAccessibilityV82(unittest.TestCase):
 def test_sound_files_are_valid_small_pcm_mono(self):
  for name in ['success','celebrate','retry']:
   path=ROOT/'assets/audio'/f'feedback_{name}.wav'
   with self.subTest(name=name),wave.open(str(path),'rb') as f:
    self.assertEqual(f.getnchannels(),1)
    self.assertEqual(f.getsampwidth(),2)
    self.assertEqual(f.getframerate(),22050)
    self.assertGreater(f.getnframes(),2000)
    self.assertLess(f.getnframes(),22050)
    self.assertLess(path.stat().st_size,50000)
 def test_sound_opt_out_persisted(self):
  self.assertIn('sound_enabled = bool(profile.get("sound_enabled", true))',MAIN)
  self.assertIn('profile["sound_enabled"] = sound_enabled',MAIN)
  self.assertIn('if not sound_enabled:\n  return',MAIN)
 def test_reduced_motion_opt_out_persisted(self):
  self.assertIn('reduced_motion = bool(profile.get("reduced_motion", false))',MAIN)
  self.assertIn('profile["reduced_motion"] = reduced_motion',MAIN)
  self.assertIn('root.modulate.a = 1.0',MAIN)
  self.assertNotIn('root.modulate.a = 0.0',MAIN)
  self.assertIn('if reduced_motion:\n  target.scale = Vector2.ONE',MAIN)
 def test_english_arabic_only_in_language_selector(self):
  section=MAIN.split('func show_languages() -> void:',1)[1].split('\nfunc ',1)[0]
  self.assertIn('for key in ["ar", "en"]:',section)
  self.assertNotIn('Türkçe',section)
  self.assertIn('if selected_language not in ["ar", "en"]:',MAIN)
  self.assertIn('selected_language = ["ar", "en"]',MAIN)
 def test_sounds_are_only_local_bundled_assets(self):
  section=MAIN.split('func play_feedback(effect: String) -> void:',1)[1].split('\nfunc ',1)[0]
  self.assertIn('res://assets/audio/feedback_',section)
  self.assertIn('ResourceLoader.exists(path)',section)
  self.assertNotIn('http',section)
  self.assertNotIn('request(',section)
 def test_gameplay_events_are_wired(self):
  self.assertIn('play_feedback("success" if correct else "retry")',MAIN)
  self.assertIn('play_feedback("celebrate" if won_now else "retry")',MAIN)
  self.assertIn('play_feedback("celebrate" if last_match_won else "retry")',MAIN)

if __name__=='__main__': unittest.main()
