import hashlib,json,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
class FinalImages(unittest.TestCase):
 def test_200_catalog_assets_and_translations(self):
  catalog=json.loads((ROOT/'data/guess_picture_302/catalog.json').read_text(encoding='utf-8'))
  cards=json.loads((ROOT/'data/cards.json').read_text(encoding='utf-8'))['cards']
  self.assertEqual(len(cards),200);self.assertEqual(len(catalog['items']),200)
  self.assertEqual(len({x['id'] for x in catalog['items']}),200)
  hashes=[]
  for x in catalog['items']:
   p=ROOT/x['image'].removeprefix('res://');hashes.append(hashlib.sha256(p.read_bytes()).hexdigest())
   with Image.open(p) as image:image.load();self.assertGreaterEqual(min(image.size),256)
   for lang in ('ar','en','tr'):self.assertTrue(x[lang].strip())
  self.assertEqual(len(set(hashes)),200)
  self.assertEqual(catalog['celebrity_integrated'],0)
 def test_options_match_card_ids_in_every_language(self):
  cards={c['image']:c for c in json.loads((ROOT/'data/cards.json').read_text(encoding='utf-8'))['cards']}
  bank=json.loads((ROOT/'data/questions.json').read_text(encoding='utf-8'))
  photos=[q for q in bank['5'] if q['id'].startswith('photo_')]
  self.assertEqual(len(photos),200)
  self.assertEqual({q['image'] for q in photos},set(cards))
  for q in photos:
   self.assertEqual(len(set(q['choice_card_ids'])),4)
   self.assertEqual(q['choice_card_ids'][q['correct']],q['image'])
   for lang in ('ar','en','tr'):
    choices=q['choices_'+lang]
    self.assertEqual(len(choices),len(set(choices)))
    self.assertEqual(choices,[cards[id][lang] for id in q['choice_card_ids']])
if __name__=='__main__':unittest.main()
