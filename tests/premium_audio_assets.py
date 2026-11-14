import json,wave,math,unittest
from array import array
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/premium'
class AudioAssets(unittest.TestCase):
 def test_original_bundle(self):
  manifest=json.loads((ROOT/'MANIFEST.json').read_text())
  self.assertEqual(len(manifest['files']),14)
  for row in manifest['files']:
   with self.subTest(file=row['file']):
    with wave.open(str(ROOT/row['file']),'rb') as w:
     self.assertEqual((w.getnchannels(),w.getsampwidth(),w.getframerate()),(1,2,22050));data=array('h',w.readframes(w.getnframes()))
    rms=math.sqrt(sum(x*x for x in data)/len(data))/32768
    self.assertGreater(rms,.005);self.assertLess(max(abs(x) for x in data),32000)
    if row['loop']:
     self.assertEqual(len(data),441000)
     self.assertLess(abs(data[0]-data[-1]),max(abs(data[i]-data[i-1]) for i in range(1,len(data))))
    else:self.assertLess(len(data)/22050,2)
if __name__=='__main__':unittest.main()
