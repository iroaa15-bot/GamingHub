import unittest,json,collections
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BANK=json.loads((ROOT/'data/questions.json').read_text())
ALL=[q for group in BANK.values() for q in group]
class ContentQuality(unittest.TestCase):
 def test_unique_ids(self):
  ids=[q['id'] for q in ALL]
  self.assertEqual(len(ids),len(set(ids)))
 def test_all_prompts_have_arabic_english(self):
  for q in ALL:
   for lang in ('ar','en'):
    self.assertTrue(str(q.get(lang,'')).strip(),(q['id'],lang))
 def test_choice_indices_and_no_duplicate_choices(self):
  for q in ALL:
   if q.get('mode','choice')!='choice':continue
   for lang in ('ar','en','tr'):
    choices=q.get('choices_'+lang,[])
    self.assertGreaterEqual(len(choices),2,(q['id'],lang))
    self.assertEqual(len(choices),len(set(choices)),(q['id'],lang))
    self.assertTrue(0<=q.get('correct',-1)<len(choices),(q['id'],lang))
 def test_picture_assets_exist(self):
  for q in ALL:
   if 'image' in q:
    path=ROOT/'assets/generated'/(q['image']+'.webp')
    self.assertTrue(path.exists(),(q['id'],path))
 def test_picture_expansion_has_25_new_rounds(self):
  self.assertEqual(sum(q['id'].startswith('visual_v36_') for q in ALL),25)
 def test_new_factual_questions_present(self):
  self.assertEqual(sum(q['id'].startswith('curated_v36_') for q in ALL),18)
 def test_new_questions_have_explanations(self):
  for q in ALL:
   if q['id'].startswith(('visual_v36_','curated_v36_')):
    self.assertTrue(q.get('explain_ar'))
    self.assertTrue(q.get('explain_en'))
if __name__=='__main__':unittest.main()
