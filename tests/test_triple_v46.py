import unittest,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class TripleValueTests(unittest.TestCase):
 def test_count_and_unique(self):
  d=json.loads((ROOT/'data/questions.json').read_text());qs=[q for arr in d.values() for q in arr]
  self.assertEqual(len(qs),2153)
  self.assertEqual(len({q['id'] for q in qs}),2153)
  self.assertEqual(sum(q['id'].startswith('arcade_v107_') for q in qs),50)
 def test_added_content_quality(self):
  d=json.loads((ROOT/'data/questions.json').read_text());qs=[q for arr in d.values() for q in arr if q['id'].startswith('quest_v46_')]
  self.assertEqual(len(qs),1402)
  for q in qs:
   for lang in ('ar','en'):
    self.assertTrue(q[lang]);self.assertTrue(q['explain_'+lang]);self.assertEqual(len(set(q['choices_'+lang])),4)
    self.assertEqual(q['choices_'+lang][q['correct']],q['explain_en'].split(' = ')[-1] if ' = ' in q['explain_en'] else q['choices_'+lang][q['correct']])
 def test_world_count(self):
  s=(ROOT/'scripts/main.gd').read_text();self.assertIn('JOURNEY_STAGE_COUNT: int = 180',s)
  line=next(x for x in s.splitlines() if x.startswith('const JOURNEY_WORLDS:'))
  self.assertEqual(line.count('"')//2,15)
 def test_old_worlds_and_games_retained(self):
  s=(ROOT/'scripts/main.gd').read_text();self.assertIn('"island", "city", "space", "mystery", "arena"',s)
if __name__=='__main__':unittest.main()
