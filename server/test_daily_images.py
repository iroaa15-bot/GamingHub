import asyncio, datetime, hashlib, json, unittest
from daily_images import CATALOG, PER_DAY, REVIEW_ONLY_PEOPLE, illustration, image_for_filename, pack, public_json
from server import http_health

class DailyPictureTests(unittest.TestCase):
    def test_pack_has_six_valid_images_and_four_unique_answers(self):
        today = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
        p = pack(today)
        self.assertEqual(p['schema'], 3)
        self.assertEqual(len(p['puzzles']), PER_DAY)
        self.assertEqual(len({x['category'] for x in p['puzzles']}), PER_DAY)
        for row in p['puzzles']:
            self.assertEqual(len(row['choices_ar']), 4)
            self.assertEqual(len(set(row['choices_ar'])), 4)
            self.assertEqual(len(set(row['choices_en'])), 4)
            self.assertTrue(0 <= row['correct_index'] < 4)
            content = image_for_filename(row['image'])
            self.assertTrue(content.startswith(b'\x89PNG\r\n\x1a\n'))
            self.assertEqual(hashlib.sha256(content).hexdigest(), row['sha256'])

    def test_determinism_and_daily_rotation(self):
        a = pack('2026-10-14')
        b = pack('2026-10-14')
        c = pack('2026-10-15')
        self.assertEqual(a, b)
        self.assertNotEqual([x['id'] for x in a['puzzles']], [x['id'] for x in c['puzzles']])

    def test_people_categories_are_not_automatically_published(self):
        self.assertTrue({'footballers', 'actors', 'singers', 'celebrities'} <= set(REVIEW_ONLY_PEOPLE))
        self.assertFalse(set(REVIEW_ONLY_PEOPLE) & set(CATALOG))
        for entries in REVIEW_ONLY_PEOPLE.values():
            self.assertTrue(all(not item[0].startswith(('Actor ', 'Singer ', 'Celebrity ', 'Football star ')) for item in entries))

    def test_path_traversal_and_stale_dates_are_rejected(self):
        self.assertIsNone(image_for_filename('../secret.txt'))
        self.assertIsNone(image_for_filename('daily-2020-01-01-00.png'))
        self.assertIsNone(image_for_filename('daily-' + datetime.datetime.now(datetime.timezone.utc).date().isoformat() + '-99.png'))

    def test_http_endpoints(self):
        class Request:
            def __init__(self, path): self.path = path
        today=datetime.datetime.now(datetime.timezone.utc).date().isoformat()
        response=asyncio.run(http_health(None,Request('/ai_daily/daily.json')))
        self.assertEqual(response.status_code, 200)
        data=json.loads(response.body)
        self.assertEqual(len(data['puzzles']),PER_DAY)
        name=data['puzzles'][0]['image']
        img=asyncio.run(http_health(None,Request('/ai_daily/'+name)))
        self.assertEqual(img.status_code,200)
        self.assertEqual(hashlib.sha256(img.body).hexdigest(), data['puzzles'][0]['sha256'])
        invalid=asyncio.run(http_health(None,Request('/ai_daily/../../secret.txt')))
        self.assertEqual(invalid.status_code,404)

if __name__ == '__main__': unittest.main()
