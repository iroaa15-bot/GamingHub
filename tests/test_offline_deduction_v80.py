import unittest
from pathlib import Path
SRC=(Path(__file__).resolve().parents[1]/'scripts/main.gd').read_text(encoding='utf-8')
class OfflineDeductionV80(unittest.TestCase):
 def test_picker_visible_to_every_audience(self):
  block=SRC.split('func show_picture_game() -> void:',1)[1].split('func ask_picture_question(',1)[0]
  self.assertNotIn('if audience == "children":',block)
  self.assertIn('for card in player_candidates.slice(',block)
  self.assertIn('submit_picture_guess(guessed_name)',block)
 def test_question_resets_pagination(self):
  block=SRC.split('func ask_picture_question(',1)[1].split('func rival_personality_name(',1)[0]
  self.assertIn('card_name_page = 0',block)
 def test_wrong_guess_eliminates_candidate(self):
  block=SRC.split('func submit_picture_guess(',1)[1].split('func record_picture_end(',1)[0]
  self.assertIn('remaining_guesses',block)
  self.assertIn('not matches_card_guess(guess, candidate)',block)
if __name__=='__main__': unittest.main()
