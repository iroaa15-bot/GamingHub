"""Regression guards for round integrity; source checks are not runtime tests."""
import unittest
from pathlib import Path
SRC=(Path(__file__).resolve().parents[1]/'scripts/main.gd').read_text(encoding='utf-8')
def block(name,next_name):
    return SRC.split('func '+name+'(',1)[1].split('func '+next_name+'(',1)[0]
class RoundIntegrityTests(unittest.TestCase):
    def test_reward_once(self):
        b=block('finish_match','claim_liveops')
        self.assertIn('if match_reward_committed:',b)
        self.assertLess(b.index('match_reward_committed = true'),b.index('LiveOps.update'))
    def test_reset_reward_guard(self):
        self.assertIn('match_reward_committed = false',block('start_game','show_round'))
    def test_survival_accuracy_uses_attempts(self):
        b=block('show_results','show_achievements')
        self.assertIn('question_index + 1 if mode_finished_early',b)
        self.assertIn('correct_count / maxi(1, attempted)',b)
    def test_no_hint_isolated(self):
        self.assertIn('or campaign_active or family_active or daily_match',block('show_round','finish_round'))
    def test_bounds_check(self):
        self.assertIn('question_index >= round_bank.size()',block('show_round','finish_round'))
if __name__ == '__main__':unittest.main()
