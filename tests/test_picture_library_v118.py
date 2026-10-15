"""Verify real independent assets and the additive daily selection contract."""
import datetime
import hashlib
import json
import unittest
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = json.loads((ROOT / 'data/picture_library.json').read_text(encoding='utf-8'))['items']
NEW_CARDS = json.loads((ROOT / 'data/picture_library_cards.json').read_text(encoding='utf-8'))['cards']
LEGACY = json.loads((ROOT / 'data/cards.json').read_text(encoding='utf-8'))


class PictureLibraryV118(unittest.TestCase):
    def test_every_entry_is_a_distinct_decodable_image_and_bilingual_quiz(self):
        self.assertEqual(len(LIBRARY), 32)
        self.assertEqual(sum(x['source'].startswith('user_handoff') for x in LIBRARY), 8)
        self.assertEqual(len({x['image'] for x in LIBRARY}), len(LIBRARY))
        self.assertEqual(len({x['sha256'] for x in LIBRARY}), len(LIBRARY))
        for row in LIBRARY:
            self.assertTrue(row['image'].startswith('res://assets/'))
            path = ROOT / row['image'].removeprefix('res://')
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), row['sha256'])
            with Image.open(path) as image:
                image.verify()
            with Image.open(path) as image:
                self.assertGreaterEqual(min(image.size), 256)
                self.assertLessEqual(max(image.size), 2048)
            self.assertIn(row['difficulty'], (1, 2, 3))
            self.assertTrue(row['question_ar'] and row['question_en'])
            self.assertEqual(len(set(row['choices_ar'])), 4)
            self.assertEqual(len(set(row['choices_en'])), 4)
            idx = row['correct_index']
            self.assertEqual(row['choices_ar'][idx], row['answer_ar'])
            self.assertEqual(row['choices_en'][idx], row['answer_en'])
            self.assertNotIn(row['category'], ('actors', 'footballers', 'celebrities', 'singers'))

    def test_legacy_deck_is_preserved_and_three_new_subjects_extend_it(self):
        self.assertEqual(len(LEGACY['cards']), 24)
        self.assertEqual({x['name'] for x in NEW_CARDS}, {'Carrot', 'Tomato', 'Chair'})
        legacy_names = {x['name'] for x in LEGACY['cards']}
        self.assertFalse(legacy_names & {x['name'] for x in NEW_CARDS})
        keys = {x['key'] for x in LEGACY['questions']}
        for card in NEW_CARDS:
            self.assertTrue(keys <= set(card))
            self.assertTrue(card['fact_ar'] and card['fact_en'] and card['fact_tr'])

    def test_daily_cycle_avoids_subject_repeats_for_three_prior_days(self):
        groups = defaultdict(list)
        for row in LIBRARY:
            groups[row['subject_key']].append(row)
        preferred = ['elephant', 'eiffel', 'banana', 'carrot', 'pizza', 'apple', 'tomato', 'chair', 'lion', 'lighthouse', 'guitar', 'burger', 'dolphin', 'bicycle', 'pyramids', 'cake', 'giraffe', 'camera', 'panda', 'football', 'taj_mahal', 'sushi', 'penguin', 'strawberry', 'tiger', 'laptop', 'violin']
        subjects = [x for x in preferred if x in groups] + sorted(set(groups) - set(preferred))
        self.assertGreaterEqual(len(subjects), 24)
        seen_recent = []
        used_images = set()
        for day_index in range(15):
            today = [subjects[(day_index * 6 + slot) % len(subjects)] for slot in range(6)]
            self.assertEqual(len(set(today)), 6)
            self.assertGreaterEqual(len({groups[subject][0]['category'] for subject in today}), 4)
            self.assertFalse(set(today) & set().union(*seen_recent[-3:]))
            seen_recent.append(today)
            for slot, subject in enumerate(today):
                variants = sorted(groups[subject], key=lambda r: not r['source'].startswith('user_handoff'))
                serial = day_index * 6 + slot
                used_images.add(variants[(serial // len(subjects)) % len(variants)]['id'])
        self.assertEqual(len(used_images), 32)
        self.assertGreaterEqual(len({x['category'] for x in LIBRARY}), 6)


if __name__ == '__main__':
    unittest.main()
