import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GAME=(ROOT/'scripts/main.gd').read_text(encoding='utf-8')
TEXT=(ROOT/'scripts/daily_rounds.gd').read_text(encoding='utf-8')
IMAGE=(ROOT/'scripts/daily_ai.gd').read_text(encoding='utf-8')
class AdditiveClientContract(unittest.TestCase):
 def test_rebuild_newest_first_without_removing_old_packs(self):
  self.assertIn('for daily_pack in DailyRounds.history:',GAME)
  self.assertIn('combined.append_array(bundled)',GAME)
  self.assertIn('round_bank = (featured + others).slice(',GAME)
  self.assertIn('dates.reverse()',TEXT)
  self.assertIn('if not by_date.has(key):',TEXT)
 def test_offline_storage_and_history_loading(self):
  self.assertIn('user://daily_rounds_history_v2.json',TEXT)
  self.assertIn('func load_older()',TEXT)
  self.assertIn('user://daily_pictures_history_v2.json',IMAGE)
  self.assertIn('func load_older()',IMAGE)
  self.assertIn('ids.reverse()',IMAGE)
  self.assertIn('FileAccess.get_file_as_bytes(cache_path)',IMAGE)
 def test_new_picture_focus_on_refresh_and_safe_picture_cache(self):
  self.assertIn('before.is_empty()',IMAGE)
  self.assertIn('if not prefer_latest and not previous_id.is_empty():',IMAGE)
  self.assertIn('_sha256_hex(data) != expected_hash',IMAGE)
 def test_saved_claims_not_daily_reset(self):
  self.assertIn('if claims.has(pid):',GAME)
  self.assertIn('claims[pid] = correct',GAME)
if __name__=='__main__':unittest.main()
