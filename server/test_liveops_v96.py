import datetime
import json
import unittest
from pathlib import Path
from types import SimpleNamespace
from liveops_content import daily_rotation
import server

class LiveOpsV96(unittest.IsolatedAsyncioTestCase):
    def test_stable_day(self):
        day = datetime.date(2026, 10, 13)
        self.assertEqual(daily_rotation(day), daily_rotation(day))
        self.assertEqual(daily_rotation(day)['effective_date_utc'], '2026-10-13')

    def test_week_changes_only_on_monday(self):
        a = daily_rotation(datetime.date(2026, 10, 13))
        b = daily_rotation(datetime.date(2026, 10, 18))
        self.assertEqual(a['weekly_missions'], b['weekly_missions'])
        self.assertEqual(a['event_rotation'], b['event_rotation'])
        self.assertEqual(a['effective_week_utc'], '2026-10-12')
        self.assertEqual(daily_rotation(datetime.date(2026, 10, 19))['effective_week_utc'], '2026-10-19')

    def test_rotation_has_safe_mission_types_and_bounds(self):
        for n in range(20):
            d = daily_rotation(datetime.date(2026, 10, 1) + datetime.timedelta(days=n))
            self.assertEqual(d['schema'], 1)
            self.assertEqual(len(d['daily_missions']), 2)
            self.assertEqual(len(d['weekly_missions']), 2)
            self.assertEqual(len(d['event_rotation']), 1)
            for item in d['daily_missions'] + d['weekly_missions']:
                self.assertIn(item['type'], ('matches', 'wins'))
                self.assertGreater(item['target'], 0)
                self.assertLessEqual(item['xp'], 500)

    async def test_http_content_endpoint(self):
        response = await server.http_health(None, SimpleNamespace(path='/liveops/rotation.json'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers['Content-Type'], 'application/json; charset=utf-8')
        data = json.loads(response.body)
        self.assertEqual(data['schema'], 1)
        self.assertIn('daily_missions', data)
        self.assertNotIn('players', data)

    async def test_health_and_websocket_unchanged(self):
        self.assertIsNone(await server.http_health(None, SimpleNamespace(path='/')))
        response = await server.http_health(None, SimpleNamespace(path='/health'))
        self.assertEqual(response.status_code, 200)

class ClientLiveOpsV96(unittest.TestCase):
    def test_godot_fetches_https_and_falls_back(self):
        root = Path(__file__).resolve().parents[1]
        source = (root/'scripts/live_ops.gd').read_text()
        self.assertIn('https://gaminghub-multiplayer.onrender.com/liveops/rotation.json', source)
        self.assertIn('if _valid(incoming):', source)
        self.assertIn('REFRESH_RETRY_MS', source)
        self.assertIn('CACHE_PATH', source)

    def test_admob_not_pretending_to_show_ads(self):
        root = Path(__file__).resolve().parents[1]
        config = json.loads((root/'monetization/ad_config.json').read_text())
        self.assertEqual(config['mode'], 'android_test_sdk')
        self.assertFalse(config['child_profiles_ads_enabled'])
        self.assertTrue(config['rewarded_enabled'])
        self.assertFalse(config['interstitial_enabled'])
        self.assertFalse(config['banner_enabled'])
        self.assertTrue(config['requires_verified_native_sdk'])
