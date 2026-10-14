"""v8.1 source contracts and exhaustive public-deck hint quality tests.
These are NOT Godot runtime tests."""
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MAIN=(ROOT/'scripts/main.gd').read_text(encoding='utf-8')
ONLINE=(ROOT/'scripts/multiplayer.gd').read_text(encoding='utf-8')
DATA=json.loads((ROOT/'data/cards.json').read_text(encoding='utf-8'))

class SmartPlayV81(unittest.TestCase):
    def test_offline_hint_only_uses_candidates(self):
        block=MAIN.split('func best_picture_question() -> int:',1)[1].split('func picture_question_text(',1)[0]
        self.assertIn('for candidate in player_candidates:',block)
        self.assertIn('mini(yes_count, player_candidates.size() - yes_count)',block)
        self.assertNotIn('my_secret',block)
        self.assertNotIn('rival_secret',block)

    def test_online_hint_only_uses_public_catalog(self):
        block=ONLINE.split('func _recommended_question_index() -> int:',1)[1].split('func _refresh_actions(',1)[0]
        self.assertIn('for card in possible_cards:',block)
        self.assertNotIn('opponent_card',block)
        self.assertNotIn('your_card',block)
        self.assertIn('mini(yes_count, possible_cards.size() - yes_count)',block)

    def test_used_questions_removed_from_paging(self):
        self.assertIn('available_picture_questions()',MAIN)
        self.assertIn('if i not in asked:',MAIN)
        self.assertIn('if i in asked_questions:',ONLINE)
        self.assertIn('available.slice(start_index,',ONLINE)

    def test_question_page_resets_after_answer(self):
        self.assertIn('asked.append(qi)\n picture_question_page = 0',MAIN)
        self.assertIn('possible_cards = remaining\n candidate_page = 0\n question_page = 0',ONLINE)

    def test_best_public_question_always_splits_when_possible(self):
        cards=DATA['cards']
        questions=DATA['questions']
        for opponent in cards:
            candidates=[c for c in cards if c['name'] != opponent['name']]
            for secret in candidates:
                remaining=candidates
                used=set()
                for _ in range(len(questions)):
                    scored=[]
                    for i,q in enumerate(questions):
                        if i in used:
                            continue
                        yes=sum(c[q['key']]==q['value'] for c in remaining)
                        balance=min(yes,len(remaining)-yes)
                        if balance>0:
                            scored.append((balance,-i,i,q))
                    if len(remaining)<=1 or not scored:
                        break
                    _,_,index,question=max(scored)
                    used.add(index)
                    truth=secret[question['key']]==question['value']
                    new_remaining=[c for c in remaining if (c[question['key']]==question['value'])==truth]
                    self.assertIn(secret,new_remaining)
                    self.assertLess(len(new_remaining),len(remaining))
                    remaining=new_remaining

    def test_card_frames_and_progress_indicators_present(self):
        self.assertIn('art_frame := PanelContainer.new()',MAIN)
        self.assertIn('deduction_progress(',MAIN)
        self.assertIn('art_frame := PanelContainer.new()',ONLINE)
        self.assertIn('deduction_bar := ProgressBar.new()',ONLINE)

if __name__=='__main__': unittest.main()
