import unittest
from pathlib import Path
S=(Path(__file__).resolve().parents[1]/"scripts/main.gd").read_text()
class MemoryVaultContract(unittest.TestCase):
 def test_entrypoint(self):
  self.assertIn('start_memory_vault, GREEN)',S)
 def test_recall_hides_sequence(self):
  recall=S.split('elif vault_phase == "recall":')[1].split('elif vault_phase == "failed":')[0]
  self.assertNotIn('VAULT_SYMBOLS[value]',recall)
 def test_reward_only_on_completion(self):
  block=S.split('func vault_choose(symbol: int) -> void:')[1].split('func vault_next()')[0]
  self.assertIn('vault_input.size() == vault_sequence.size()',block)
  self.assertIn('save_progress()',block)
 def test_five_rounds(self):
  self.assertIn('vault_level >= 5',S)
 def test_original_adventure_retained(self):
  self.assertIn('func start_expedition()',S)
