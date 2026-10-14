"""New-mode source/content regressions; true Godot runtime checks live in godot_smoke.gd."""
import json
import re
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SRC = (ROOT/'scripts/main.gd').read_text(encoding='utf-8')
BANK = json.loads((ROOT/'data/questions.json').read_text(encoding='utf-8'))
CONFIG = json.loads((ROOT/'monetization/ad_config.json').read_text(encoding='utf-8'))

class ArcadeV107(unittest.TestCase):
 def test_modes_exist_with_real_gameplay(self):
  for mode, method in [('blitz','start_blitz_clock'),('treasure','claim_treasure')]:
   self.assertIn('choose_match_style("'+mode+'")', SRC)
   self.assertIn('func '+method+'(',SRC)
  self.assertIn('blitz_timer.timeout.connect(blitz_timeout)',SRC)
  self.assertIn('finish_round(false, correct_answer_text(',SRC)
  self.assertIn('blitz_last_bonus = mini(15',SRC)

 def test_rewards_are_earned_only_from_quiz_gameplay(self):
  self.assertIn('treasure_keys += 1',SRC)
  self.assertIn('treasure_keys -= 2',SRC)
  self.assertIn('treasure_latest_checkpoint == question_index',SRC)
  self.assertIn('treasure_doubles -= 1',SRC)
  self.assertIn('treasure_shields -= 1',SRC)
  self.assertIn('treasure_doubled_this_round = true',SRC)

 def test_quick_sessions_and_anti_repeat(self):
  self.assertIn('session_length = previous_length',SRC)
  self.assertIn('arcade_variety_order(fresh_questions)',SRC)
  self.assertIn('arcade_variety_order(familiar_questions)',SRC)
  self.assertIn('if str(question.get("id", "")) in recent_ids:',SRC)

 def test_new_contents_have_correct_formats(self):
  new = [(k,q) for k,g in BANK.items() for q in g if q['id'].startswith('arcade_v107_')]
  self.assertEqual(len(new),50)
  self.assertGreaterEqual(len(set(k for k,_ in new)),6)
  self.assertEqual(len({q['id'] for _,q in new}),len(new))
  for game,q in new:
   self.assertTrue(q['ar'].strip())
   self.assertTrue(q['en'].strip())
   self.assertIn(int(q['level']),(1,2,3))
   self.assertTrue(q['explain_ar'].strip())
   self.assertTrue(q['explain_en'].strip())
   if q.get('mode','choice') == 'choice':
    for lang in ('ar','en'):
     options=q['choices_'+lang]
     self.assertEqual(4,len(options),(game,q['id']))
     self.assertEqual(4,len(set(options)),(game,q['id']))
     self.assertTrue(0<=q['correct']<4)
   else:
    self.assertEqual(q['mode'],'order')
    self.assertEqual(len(q['steps_ar']),len(q['steps_en']))
    self.assertGreaterEqual(len(q['steps_ar']),3)

 def test_no_fake_ad_rewards_added(self):
  self.assertEqual(CONFIG['mode'],'android_test_sdk')
  self.assertTrue(CONFIG['rewarded_enabled'])
  self.assertFalse(CONFIG['banner_enabled'])
  self.assertFalse(CONFIG['interstitial_enabled'])

 def test_ci_smoke_includes_new_modes(self):
  gd=(ROOT/'tests/godot_smoke.gd').read_text(encoding='utf-8')
  self.assertIn('func _check_arcade_modes()',gd)
  self.assertIn('hub.claim_treasure("double")',gd)
  self.assertIn('await _check_arcade_modes()',gd)

if __name__ == '__main__':
 unittest.main()
