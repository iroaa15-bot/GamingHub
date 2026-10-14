import datetime as dt
import json
import unittest
from types import SimpleNamespace

from daily_content import PER_DAY, _words_ar, _words_en, daily_pack, json_bytes, validate_pack
import server


class DailyContentTests(unittest.IsolatedAsyncioTestCase):
    def test_deterministic_and_correct(self):
        today = dt.date(2026, 10, 14)
        first = daily_pack(today)
        self.assertEqual(first, daily_pack(today))
        validate_pack(first, today)
        self.assertEqual(len(first['questions']), PER_DAY)
        self.assertEqual({q['game'] for q in first['questions']}, {'2', '3', '5'})
        self.assertTrue(all(q['choices_ar'][q['correct']] == q['choices_en'][q['correct']] for q in first['questions']))

    def test_next_day_differs(self):
        a = daily_pack(dt.date(2026, 10, 14))
        b = daily_pack(dt.date(2026, 10, 15))
        self.assertNotEqual(a['sha256'], b['sha256'])
        self.assertFalse({q['en'] for q in a['questions']} & {q['en'] for q in b['questions']})

    def test_word_transliteration(self):
        self.assertEqual(_words_en(27), 'twenty-seven')
        self.assertEqual(_words_ar(27), 'سبعة وعشرون')
        self.assertEqual(_words_en(305), 'three hundred and five')
        self.assertEqual(_words_ar(305), 'ثلاثمائة وخمسة')

    def test_tampered_pack_rejected(self):
        today = dt.date(2026, 10, 14)
        data = json.loads(json.dumps(daily_pack(today)))
        data['questions'][0]['correct'] = (data['questions'][0]['correct'] + 1) % 4
        with self.assertRaises(ValueError):
            validate_pack(data, today)

    async def test_http_daily_endpoint(self):
        response = await server.http_health(None, SimpleNamespace(path='/content/daily.json'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers['Content-Type'], 'application/json; charset=utf-8')
        body = json.loads(response.body)
        validate_pack(body)
        self.assertNotIn('email', response.body.decode('utf-8'))

    async def test_existing_matchmaking_and_health(self):
        self.assertIsNone(await server.http_health(None, SimpleNamespace(path='/')))
        response = await server.http_health(None, SimpleNamespace(path='/health'))
        self.assertEqual(response.status_code, 200)

    def test_duplicates_within_rolling_window(self):
        seen = {}
        start = dt.date(2026, 10, 14)
        for offset in range(100):
            date = start + dt.timedelta(days=offset)
            pack = daily_pack(date)
            validate_pack(pack, date)
            for question in pack['questions']:
                if question['en'] in seen:
                    self.assertGreaterEqual((date - seen[question['en']]).days, 90, question['en'])
                seen[question['en']] = date


if __name__ == '__main__':
    unittest.main()
