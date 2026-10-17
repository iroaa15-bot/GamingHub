"""Verify real independent assets and the additive daily selection contract."""
import datetime
import hashlib
import json
import unittest
from collections import Counter, defaultdict
from pathlib import Path
from xml.etree import ElementTree

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = json.loads((ROOT / 'data/picture_library.json').read_text(encoding='utf-8'))['items']
NEW_CARDS = json.loads((ROOT / 'data/picture_library_cards.json').read_text(encoding='utf-8'))['cards']
LEGACY = json.loads((ROOT / 'data/cards.json').read_text(encoding='utf-8'))


class PictureLibraryV118(unittest.TestCase):
    def test_every_entry_is_a_distinct_decodable_image_and_bilingual_quiz(self):
        self.assertEqual(len(LIBRARY), 100)
        self.assertEqual(sum(x['source'].startswith('user_handoff') for x in LIBRARY), 8)
        self.assertEqual(sum(x['source'].startswith('twemoji') for x in LIBRARY), 68)
        self.assertEqual(len({x['image'] for x in LIBRARY}), len(LIBRARY))
        self.assertEqual(len({x['sha256'] for x in LIBRARY}), len(LIBRARY))
        for row in LIBRARY:
            self.assertTrue(row['image'].startswith('res://assets/'))
            path = ROOT / row['image'].removeprefix('res://')
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), row['sha256'])
            if path.suffix == '.svg':
                svg = ElementTree.parse(path).getroot()
                self.assertEqual(svg.tag, '{http://www.w3.org/2000/svg}svg')
                view_box = [float(value) for value in svg.attrib['viewBox'].split()]
                self.assertEqual(len(view_box), 4)
                self.assertGreater(view_box[2], 0)
                self.assertGreater(view_box[3], 0)
                self.assertEqual(row['license_url'], 'https://creativecommons.org/licenses/by/4.0/')
                self.assertIn('twitter', row['attribution'].lower())
                self.assertRegex(row['source_url'], r'/[0-9a-f]+\.svg$')
                self.assertIn('svg/scale=8.0', (path.with_suffix('.svg.import')).read_text(encoding='utf-8'))
            else:
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
        by_category = defaultdict(list)
        for row in LIBRARY:
            groups[row['subject_key']].append(row)
        for prefix in ('user_handoff', 'twemoji', 'existing'):
            for row in LIBRARY:
                if row['source'].startswith(prefix) and row['subject_key'] not in by_category[row['category']]:
                    by_category[row['category']].append(row['subject_key'])
        categories = ['animals', 'fruits', 'vegetables', 'food', 'objects', 'landmarks']
        self.assertEqual(len(set(groups)), 95)
        self.assertTrue(all(len(by_category[cat]) >= 7 for cat in categories))
        seen_recent = []
        used_images = set()
        for day_index in range(80):
            today = [by_category[cat][day_index % len(by_category[cat])]
                     for cat in categories]
            self.assertEqual(len(set(today)), 6)
            self.assertEqual(len({groups[subject][0]['category'] for subject in today}), 6)
            self.assertFalse(set(today) & set().union(*seen_recent[-3:]))
            seen_recent.append(today)
            for cat, subject in zip(categories, today):
                variants = sorted(groups[subject], key=lambda r: not r['source'].startswith('user_handoff'))
                used_images.add(variants[(day_index // len(by_category[cat])) % len(variants)]['id'])
        self.assertEqual(len(used_images), 100)
        self.assertGreaterEqual(len({x['category'] for x in LIBRARY}), 6)


if __name__ == '__main__':
    unittest.main()
