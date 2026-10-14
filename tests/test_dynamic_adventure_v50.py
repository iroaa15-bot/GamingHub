from pathlib import Path
import unittest,re
S=(Path(__file__).resolve().parents[1]/'scripts/main.gd').read_text()
class DynamicAdventure(unittest.TestCase):
 def test_random_puzzle(self):
  self.assertIn('func chain_prepare_code()',S)
  self.assertIn('randi_range(2, 12)',S)
  self.assertIn('chain_code_options.shuffle()',S)
 def test_answer_not_hardcoded(self):
  self.assertIn('value == chain_code_answer',S)
  self.assertNotIn('value == 21',S)
 def test_wrong_answer_retry(self):
  body=S.split('func chain_answer(',1)[1].split('func chain_final(',1)[0]
  self.assertIn('chain_code_attempts += 1',body)
  self.assertIn('chain_hearts -= 1',body)
  self.assertIn('chain_stage = 3',body)
 def test_old_content(self):
  for key in ['start_expedition','start_memory_vault','start_adventure_chain','show_picture_game','show_journey_map']:
   self.assertIn('func '+key+'(',S)
if __name__=='__main__':unittest.main()
