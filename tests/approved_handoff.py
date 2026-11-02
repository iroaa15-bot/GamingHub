import sys,json,unittest,hashlib,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'server'));sys.path.insert(0,str(ROOT/'tools'))
from approved_content import pictures,question_bank,question_allowed
from photo_duel_filters_local import FilterHub
from audit_handoff import arithmetic
from shared_quiz_local import SharedQuizHub
class ApprovedAdditions(unittest.TestCase):
 def test_actual_approved_assets_and_legacy_preservation(self):
  extra=pictures();self.assertEqual(len(extra['cards']),28)
  self.assertEqual(len({c['name'] for c in extra['cards']}),28)
  baseline=json.loads(subprocess.check_output(['git','show','4e02386377e082ceae2a8cd724680b5b5506740d:data/cards.json'],cwd=ROOT))
  self.assertEqual(json.loads((ROOT/'data/cards.json').read_text(encoding='utf-8')),baseline)
  audit=json.loads((ROOT/'release/master_integration_20261102/photo_decisions.json').read_text(encoding='utf-8'))
  for row in audit:
   if row['decision']!='APPROVED_DEVELOPMENT':continue
   data=(ROOT/row['asset'][6:]).read_bytes();self.assertEqual(hashlib.sha256(data).hexdigest(),row['sha256'])
  hub=FilterHub();self.assertEqual(len(hub.catalog),228);self.assertEqual(len(hub.filter_items),228)
  self.assertEqual(sum(v['group']=='original_200' for v in hub.catalog.values()),200)
  self.assertEqual(len({c['image'] for c in hub.catalog.values()}),228)
  self.assertTrue(all(type(v) is bool for c in extra['catalog'] for v in c['facts'].values()))
 def test_verified_questions_and_no_staging_leak(self):
  bank=question_bank();extra=json.loads((ROOT/'data/approved_content/questions.json').read_text(encoding='utf-8'))['questions']
  ids=[q['id'] for group in bank.values() for q in group];self.assertEqual(len(ids),len(set(ids)))
  self.assertEqual(sum(map(len,extra.values())),8)
  self.assertTrue(all(question_allowed(q) for group in bank.values() for q in group))
  self.assertFalse(question_allowed({'id':'core_3_0','ar':'2، 4، 6'}))
  self.assertTrue(question_allowed({'id':'date_fixture','topic':'numbers','ar':'في أي عام انتهت الحرب العالمية الثانية؟ 1945 أم 1940؟'}))
  self.assertTrue(question_allowed({'id':'logical_fixture','topic':'logic','ar':'تجاوزت صاحب المركز الثاني. ما مركزك؟'}))
  self.assertFalse(question_allowed({'topic':'logic','ar':'ما ناتج 5 + 3؟'}))
  for game,group in extra.items():
   for q in group:
    self.assertIn(q,bank[game]);self.assertFalse(arithmetic(q['ar']))
    self.assertEqual(q['review']['status'],'VERIFIED_EDITORIAL')
  approved={q['id'] for group in extra.values() for q in group}
  review=json.loads((ROOT/'release/master_integration_20261102/questions_review.json').read_text(encoding='utf-8'))
  self.assertTrue(all(row['id'] not in ids for row in review if row['id'] not in approved))
  hub=SharedQuizHub('t'*64,':memory:')
  try:
   for game,group in extra.items():
    for q in group:
     for repeat in range(30):
      public,correct=hub.adapters[game].public(q)
      for lang in ('ar','en','tr'):self.assertEqual(public['choices_'+lang][correct],q['choices_'+lang][q['correct']])
      self.assertNotIn('correct',public)
  finally:hub.moderation.db.close()
  self.assertTrue(arithmetic('ما ناتج 5 + 3؟'));self.assertTrue(arithmetic('احسب مجموع الأعداد'));self.assertFalse(arithmetic('أي كوكب في مجموعتنا الشمسية؟'))
if __name__=='__main__':unittest.main()
