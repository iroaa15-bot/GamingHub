"""v8.3 offline contracts and asset validation; does not simulate Godot runtime."""
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MAIN=(ROOT/'scripts/main.gd').read_text(encoding='utf-8')
REPORT=json.loads((ROOT/'release/ASSET_OPTIMIZATION_v8.3.json').read_text())

def webp_size(path: Path) -> tuple[int,int]:
 """Read the lossy VP8 frame header using the standard library."""
 raw=path.read_bytes()[:40]
 if raw[:4]!=b'RIFF' or raw[8:12]!=b'WEBP' or raw[12:16]!=b'VP8 ' or raw[23:26]!=b'\x9d\x01\x2a':
  raise ValueError(f'Unexpected WebP frame header: {path}')
 return (int.from_bytes(raw[26:28],'little') & 0x3fff, int.from_bytes(raw[28:30],'little') & 0x3fff)

class PerformanceRewardsV83(unittest.TestCase):
 def test_bounded_texture_cache(self):
  self.assertIn('const TEXTURE_CACHE_LIMIT: int = 10', MAIN)
  self.assertIn('while texture_cache_order.size() > TEXTURE_CACHE_LIMIT:', MAIN)
  self.assertIn('texture_cache.erase(oldest)', MAIN)
  self.assertIn('if not ResourceLoader.exists(path):', MAIN)
  self.assertIn('if path.is_empty() or not path.begins_with("res://assets/"):',MAIN)
 def test_card_memory_and_campaign_share_cache(self):
  self.assertIn('return cached_texture(generated)',MAIN)
  self.assertIn('art.texture = cached_texture(path)',MAIN)
  self.assertIn('art.texture = cached_texture(str(scenes[act]))',MAIN)
 def test_optimized_worlds_exist_and_references_updated(self):
  self.assertNotIn('world_%d.png',MAIN)
  for i in range(5):
   file=ROOT/'assets/ui'/f'world_{i}.webp'
   self.assertTrue(file.exists())
   self.assertEqual(webp_size(file),(640,370))
   self.assertFalse(file.with_suffix('.png').exists())
 def test_generated_cards_remain_legible_resolution(self):
  for file in (ROOT/'assets/generated').glob('*.webp'):
   with self.subTest(file=file.name):
    size=webp_size(file)
    self.assertGreaterEqual(min(size), 480)
    self.assertLessEqual(max(size), 872)
 def test_asset_bytes_reduced_and_report_accurate(self):
  self.assertEqual(REPORT['count'],30)
  self.assertLess(REPORT['optimized_bytes'],REPORT['original_bytes']*0.5)
  self.assertEqual(REPORT['optimized_bytes'],sum((ROOT/x['path']).stat().st_size for x in REPORT['assets']))
 def test_reward_ui_and_accuracy_medals(self):
  self.assertIn('func xp_progress() -> void:',MAIN)
  self.assertIn('var progress := ProgressBar.new()',MAIN)
  self.assertIn('progress.show_percentage = false',MAIN)
  self.assertIn('func result_medal(accuracy: int) -> String:',MAIN)
  self.assertIn('if accuracy >= 95:',MAIN)
  self.assertIn('if accuracy >= 80:',MAIN)
  self.assertIn('if accuracy >= 60:',MAIN)
  self.assertIn('medal.text = result_medal(accuracy)',MAIN)
 def test_best_accuracy_persisted_only_on_committed_match(self):
  finish=MAIN.split('func finish_match() -> void:',1)[1].split('\nfunc ',1)[0]
  self.assertIn('if match_reward_committed:',finish)
  self.assertIn('profile[accuracy_key] = maxi(',finish)
  self.assertIn('save_progress()',finish)
 def test_memory_rewards_have_progress_bar(self):
  finish=MAIN.split('func finish_memory() -> void:',1)[1].split('\nfunc ',1)[0]
  self.assertIn('xp_progress()',finish)
  self.assertIn('label(result_medal(memory_accuracy), 24)',finish)
  self.assertIn('100.0 * pairs / maxi(pairs, memory_moves)',finish)

if __name__=='__main__': unittest.main()
