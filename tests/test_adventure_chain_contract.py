from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
S=(ROOT/'scripts/main.gd').read_text()
class AdventureChainContract(unittest.TestCase):
 def test_new_flow(self):
  for name in ('start_adventure_chain','chain_route','chain_hide_pattern','chain_tap','chain_answer','chain_final','chain_check_lives','show_adventure_chain'):
   self.assertIn('func '+name+'(',S)
 def test_persistence(self):
  for field in ('chain_wins','chain_best_stars','save_progress()'):
   self.assertIn(field,S)
 def test_old_games_preserved(self):
  for name in ('start_expedition','start_memory_vault','show_journey_map','show_picture_game'):
   self.assertIn('func '+name+'(',S)
 def test_secondary_game_preserved(self):
  self.assertIn('func show_more_games()',S)
  self.assertIn('func start_adventure_chain()',S)
if __name__=='__main__': unittest.main()
