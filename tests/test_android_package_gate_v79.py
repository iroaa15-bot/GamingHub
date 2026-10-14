import pathlib, tempfile, unittest, zipfile, sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'release'))
from verify_android_package import check
class TestAndroidPackageGate(unittest.TestCase):
    def test_missing_package_fails(self):
        self.assertTrue(check(pathlib.Path('/tmp/gaminghub_not_an_actual_package.aab')))
    def test_empty_zip_fails(self):
        with tempfile.TemporaryDirectory() as td:
            path=pathlib.Path(td)/'fake.aab'
            with zipfile.ZipFile(path,'w') as z: z.writestr('README.txt','fake')
            self.assertTrue(check(path,release=True))
    def test_wrong_extension_fails(self):
        with tempfile.TemporaryDirectory() as td:
            path=pathlib.Path(td)/'fake.zip'
            with zipfile.ZipFile(path,'w') as z: z.writestr('README.txt','fake')
            self.assertTrue(check(path))
if __name__=='__main__': unittest.main()
