import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SRC=(ROOT/'scripts/main.gd').read_text()
class ExpeditionContract(unittest.TestCase):
 def test_secondary_game_preserved(self):
  self.assertIn('func show_more_games()', SRC)
  self.assertIn('func start_expedition()', SRC)
 def test_three_routes(self):
  for route in ('cave','forest','bridge'):
   self.assertIn(f'expedition_choose("{route}")',SRC)
 def test_four_stages_and_endings(self):
  for marker in ('expedition_room == 0','expedition_room == 1','expedition_room == 2','expedition_room == 3','expedition_room = 4'):
   self.assertIn(marker,SRC)
 def test_persistence_and_no_regression_removal(self):
  for marker in ('profile["expedition_wins"]','save_progress()','func show_journey_map()', 'func show_ai_daily(', 'func show_round()'):
   self.assertIn(marker,SRC)
 def test_rewards_require_success(self):
  self.assertIn('if won:',SRC)
  self.assertIn('expedition_best_reward',SRC)
if __name__=='__main__': unittest.main()
