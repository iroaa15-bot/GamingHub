import importlib.util, pathlib, tempfile, unittest, json, hashlib
HERE=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('pipeline',HERE/'generate.py')
pipeline=importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)
spec2=importlib.util.spec_from_file_location('validator',HERE/'validate_release.py')
validator=importlib.util.module_from_spec(spec2)
spec2.loader.exec_module(validator)
class PipelineTests(unittest.TestCase):
 def test_demo_cannot_approve(self):
  with tempfile.TemporaryDirectory() as d:
   previous=pipeline.OUTPUT
   try:
    pipeline.OUTPUT=pathlib.Path(d)
    pipeline.generate('2026-10-12','demo','animals')
    with self.assertRaises(RuntimeError):pipeline.approve('2026-10-12',True)
   finally:pipeline.OUTPUT=previous
 def test_categories_and_choices(self):
  with tempfile.TemporaryDirectory() as d:
   previous=pipeline.OUTPUT
   try:
    pipeline.OUTPUT=pathlib.Path(d)
    folder=pipeline.generate('2026-10-13','demo','food')
    draft=json.loads((folder/'draft.json').read_text(encoding='utf-8'))
    self.assertEqual(draft['category'],'food')
    self.assertEqual(len(draft['choices_en']),4)
    self.assertEqual(len(set(draft['choices_en'])),4)
    self.assertTrue(draft['auto_publish_allowed'])
   finally:pipeline.OUTPUT=previous
 def test_reviewed_categories_require_force_publish(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)
   img=p/'daily-2026-10-12.png'; img.write_bytes(b'\x89PNG\r\n\x1a\n'+b'x'*20)
   record={'schema':2,'id':'daily-2026-10-12','date':'2026-10-12','type':'image_guess','category':'celebrities','category_en':'Celebrities','category_ar':'مشاهير','title_en':'Guess the image','title_ar':'خمن الصورة','image':img.name,'sha256':hashlib.sha256(img.read_bytes()).hexdigest(),'status':'approved','provider':'openai','answer_verified':True,'choices_en':['Celebrity A','Celebrity B','Celebrity C','Celebrity D'],'choices_ar':['مشهور أ','مشهور ب','مشهور ج','مشهور د'],'correct_index':0,'xp':25,'reviewed_only':True,'auto_publish_allowed':False}
   (p/'daily.json').write_text(json.dumps(record,ensure_ascii=False),encoding='utf-8')
   self.assertEqual(validator.validate(p)['category'],'celebrities')
if __name__=='__main__':unittest.main()
