"""v8.5 static contracts; not a substitute for Godot runtime tests."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MAIN=(ROOT/'scripts/main.gd').read_text()
ONLINE=(ROOT/'scripts/multiplayer.gd').read_text()
class VisualResultsAndSync(unittest.TestCase):
 def test_online_uses_real_profile_path(self):
  self.assertIn('if audience != "all":\n  audience = "all"', ONLINE)
  self.assertIn('"user://progress_v10_" + audience + ".json"',ONLINE)
  self.assertIn('if saved is Dictionary:',ONLINE)
  self.assertNotIn('if saved is Dictionary and not audience.is_empty():',ONLINE)
 def test_match_outcome_is_single_source_of_truth(self):
  self.assertIn('last_match_won = won',MAIN)
  self.assertIn('play_feedback("celebrate" if last_match_won else "retry")',MAIN)
 def test_results_hero_and_stats_are_used(self):
  self.assertIn('func result_hero(accuracy: int) -> void:',MAIN)
  self.assertIn('result_hero(final_accuracy)',MAIN)
  self.assertIn('stat_strip(tr_ui("إجابات صحيحة"',MAIN)
 def test_portrait_picture_stats_without_secret_leak(self):
  picture=MAIN.split('func show_picture_game() -> void:',1)[1].split('\nfunc ',1)[0]
  self.assertIn('str(player_candidates.size())',picture)
  self.assertIn('picture_turn_limit - turns',picture)
  self.assertNotIn('str(my_secret["name"])',picture.split('if picture_done:',1)[0])
 def test_reduced_motion_avoids_result_animation(self):
  hero=MAIN.split('func result_hero(accuracy: int) -> void:',1)[1].split('\nfunc ',1)[0]
  self.assertIn('if not reduced_motion:',hero)
  self.assertIn('frame.create_tween()',hero)
 def test_online_hidden_card_label(self):
  self.assertIn('🔒 بطاقتك: ؟؟؟',ONLINE)
if __name__=='__main__': unittest.main()
