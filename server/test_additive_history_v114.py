"""Regression tests: new packs must prepend, and historical images remain available."""
import asyncio
import datetime as dt
import hashlib
import json
import unittest

from server import history_payload, http_health
from daily_images import image_for_filename

TODAY = dt.datetime.now(dt.timezone.utc).date()
EPOCH = dt.date(2026, 10, 1)

class AdditiveHistoryTests(unittest.TestCase):
    def test_text_history_has_distinct_days_and_additive_ids(self):
        data = json.loads(history_payload('text', days=3))
        days = [entry['date_utc'] for entry in data['packs']]
        self.assertEqual(days, sorted(days, reverse=True))
        self.assertEqual(len(set(days)), len(days))
        ids = [q['id'] for item in data['packs'] for q in item['questions']]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(len(ids), 24 * len(days))
        self.assertTrue(data['retains_old_content'])

    def test_image_history_shows_today_first_and_all_old_images_load(self):
        data = json.loads(history_payload('image', days=3))
        days = [entry['date_utc'] for entry in data['packs']]
        self.assertEqual(days, sorted(days, reverse=True))
        ids = set()
        for daily in data['packs']:
            self.assertEqual(len(daily['puzzles']), 6)
            for q in daily['puzzles']:
                self.assertNotIn(q['id'], ids)
                ids.add(q['id'])
                contents = image_for_filename(q['image'])
                self.assertIsNotNone(contents)
                self.assertEqual(hashlib.sha256(contents).hexdigest(), q['sha256'])

    def test_pagination_does_not_repeat_previous_days(self):
        first = json.loads(history_payload('image', days=2))
        self.assertEqual(len(first['packs']), 2)
        before = first['next_before']
        second = json.loads(history_payload('image', before=before, days=2))
        ids1 = {x['id'] for p in first['packs'] for x in p['puzzles']}
        ids2 = {x['id'] for p in second['packs'] for x in p['puzzles']}
        self.assertFalse(ids1 & ids2)

    def test_bad_dates_or_page_sizes_fail_closed(self):
        with self.assertRaises(ValueError):
            history_payload('image', before='2050-01-01')
        with self.assertRaises(ValueError):
            history_payload('text', before='not-a-date')
        with self.assertRaises(ValueError):
            history_payload('image', before='2030-01-01')

    def test_http_history_endpoints(self):
        class Request:
            def __init__(self, path): self.path = path
        response = asyncio.run(http_health(None, Request('/content/history.json?days=2')))
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.body)
        self.assertEqual(data['kind'], 'text')
        self.assertEqual(len(data['packs']), 2)
        response = asyncio.run(http_health(None, Request('/ai_daily/history.json?days=2')))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.loads(response.body)['kind'], 'image')
        response = asyncio.run(http_health(None, Request('/ai_daily/history.json?days=500')))
        self.assertEqual(response.status_code, 400)

    def test_archive_keeps_earliest_available_day(self):
        early = json.loads(history_payload('image', before=(EPOCH + dt.timedelta(days=2)).isoformat(), days=7))
        self.assertEqual(early['packs'][-1]['date_utc'], EPOCH.isoformat())
        self.assertEqual(early['next_before'], '')
        self.assertIsNotNone(image_for_filename(f'daily-{EPOCH.isoformat()}-00.png'))

if __name__ == '__main__': unittest.main()
