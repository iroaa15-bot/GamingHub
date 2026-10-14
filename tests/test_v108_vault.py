import unittest
from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'scripts/main.gd').read_text()
class VaultTests(unittest.TestCase):
 def test_mode_and_controls(self):
  for text in ('choose_match_style("vault")','func show_vault_checkpoint()', 'func vault_bank()', 'func vault_risk()', 'match_style == "vault"'):
   self.assertIn(text,s)
 def test_points_not_spendable_before_bank(self):
  self.assertIn('vault_pending += earned\n  else:\n   score += earned',s)
  self.assertIn('vault_lost += vault_pending\n   vault_pending = 0',s)
  self.assertIn('score += vault_pending\n vault_pending = 0',s)
 def test_no_double_claim(self):
  self.assertGreaterEqual(s.count('if vault_locked:\n  return'),2)
  self.assertIn('question_index % 3 == 0',s)
  self.assertIn('vault_pending = int(vault_pending * 1.5)',s)
 def test_end_of_match_banks_remaining(self):
  self.assertIn('func finish_match() -> void:\n if match_style == "vault"',s)
