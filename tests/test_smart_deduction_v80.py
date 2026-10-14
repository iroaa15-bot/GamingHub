"""Release contracts + catalog truth-table verification (not Godot runtime)."""
import json, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SRC = (ROOT/'scripts/multiplayer.gd').read_text(encoding='utf-8')
DATA = json.loads((ROOT/'data/cards.json').read_text(encoding='utf-8'))
SERVER_DATA = json.loads((ROOT/'server/cards.json').read_text(encoding='utf-8'))

class SmartDeductionV80(unittest.TestCase):
    def test_server_client_catalogs_identical(self):
        self.assertEqual(DATA, SERVER_DATA, 'Card/question drift breaks online deduction')

    def test_every_answer_preserves_secret_in_candidate_set(self):
        for secret in DATA['cards']:
            for opponent in DATA['cards']:
                if secret['name'] == opponent['name']:
                    continue
                candidates = [card for card in DATA['cards'] if card['name'] != opponent['name']]
                self.assertEqual(len(candidates), len(DATA['cards'])-1)
                for question in DATA['questions']:
                    answer = secret[question['key']] == question['value']
                    narrowed = [card for card in candidates if (card[question['key']] == question['value']) == answer]
                    self.assertIn(secret, narrowed, f"Lost secret={secret['name']} on {question['text']}")

    def test_answer_filter_is_own_player_only(self):
        question_branch = SRC.split('  "question":',1)[1].split('  "guess":',1)[0]
        self.assertIn('int(msg.get("player", -1)) == player_index',question_branch)
        self.assertIn('_apply_answer(',question_branch)

    def test_asked_questions_are_hidden_and_reset(self):
        self.assertIn('if i in asked_questions:',SRC)
        self.assertIn('asked_questions.clear()',SRC)
        self.assertIn('question_index not in asked_questions',SRC)

    def test_only_public_cards_used_for_suggestions(self):
        started = SRC.split('  "started":',1)[1].split('  "turn":',1)[0]
        self.assertIn('catalog.get("cards", [])',started)
        self.assertIn('str(item.get("name", "")) != opponent_card',started)
        self.assertNotIn('my_secret',SRC)
        self.assertNotIn('your_card',started)

    def test_wrong_guess_reduces_candidates(self):
        self.assertIn('_remove_wrong_guess(str(msg.get("guess", "")))',SRC)
        self.assertIn('not bool(msg.get("correct", false))',SRC)

    def test_two_languages_only_in_online_toggle(self):
        self.assertIn('language = ["ar", "en"]',SRC)

if __name__ == '__main__':
    unittest.main()
