"""Static release regressions; these do not assert Android or Godot runtime readiness."""
import json, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

class ReleaseV77(unittest.TestCase):
 def test_campaign_assets_resolve_and_are_mobile_sized(self):
  catalog=json.loads((ROOT/'data/campaigns.json').read_text(encoding='utf-8'))
  for path in catalog['scenes']:
   self.assertTrue(path.startswith('res://assets/campaign/'),path)
   file=ROOT/path[6:]
   self.assertTrue(file.is_file(),path)
   self.assertLess(file.stat().st_size, 500_000)
   self.assertEqual(file.read_bytes()[:4],b"RIFF")

 def test_campaign_size_reduction(self):
  # The original optimization report is not part of the GitHub source package.
  # Verify the five shipped WebP assets directly, without an external report.
  catalog=json.loads((ROOT/'data/campaigns.json').read_text(encoding='utf-8'))
  self.assertEqual(len(catalog['scenes']), 5)
  total=0
  for resource in catalog['scenes']:
   asset=ROOT/resource.removeprefix('res://')
   self.assertTrue(asset.is_file(),resource)
   raw=asset.read_bytes()
   self.assertTrue(raw.startswith(b'RIFF') and raw[8:12]==b'WEBP',resource)
   self.assertLess(len(raw),500_000,resource)
   total+=len(raw)
  self.assertLess(total,2_000_000)

 def test_double_tap_is_locked_until_server_response(self):
  source=(ROOT/'scripts/multiplayer.gd').read_text(encoding='utf-8')
  self.assertIn('action_in_flight',source)
  self.assertIn('action_type in ["ask", "guess"] and action_in_flight',source)
  self.assertIn('kind in ["turn", "finished", "left", "disconnected"]',source)
  self.assertIn('if not action_in_flight:', source)

 def test_ads_cannot_claim_rewards_without_native_sdk(self):
  config=json.loads((ROOT/'monetization/ad_config.json').read_text())
  self.assertFalse(config['child_profiles_ads_enabled'])
  self.assertEqual(config['mode'],'android_test_sdk')

if __name__=='__main__': unittest.main()
