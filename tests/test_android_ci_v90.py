"""Executable source upload and Android verifier tests, plus CI regression contracts."""
import importlib.util, tempfile, unittest, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def load_module(name, path):
    spec=importlib.util.spec_from_file_location(name, path)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

upload=load_module('upload_gate',ROOT/'release/verify_project_upload.py')
android=load_module('apk_gate',ROOT/'release/verify_android_package.py')

class ReleaseGateV90(unittest.TestCase):
    def test_full_project_inventory_passes(self):
        self.assertEqual([],upload.verify(ROOT))
    def test_backend_only_upload_fails(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertTrue(any('project.godot' in x for x in upload.verify(Path(d))))
    def test_missing_images_fail(self):
        with tempfile.TemporaryDirectory() as d:
            tmp=Path(d)
            for p in ['project.godot','export_presets.cfg','scenes/Main.tscn','scenes/Multiplayer.tscn',
                      'scripts/main.gd','scripts/multiplayer.gd','data/cards.json',
                      'assets/ui/gaming_hub_icon.png','tests/godot_smoke.gd']:
                target=tmp/p
                target.parent.mkdir(parents=True,exist_ok=True)
                target.write_text('x')
            self.assertTrue(any('assets/generated' in x for x in upload.verify(tmp)))
    def test_invalid_apk_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'test.apk'
            p.write_bytes(b'Not an APK')
            self.assertTrue(android.check(p))
    def test_missing_compiled_resources_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'test.apk'
            with zipfile.ZipFile(p,'w') as z:
                z.writestr('AndroidManifest.xml','manifest')
                z.writestr('classes.dex','dex')
                z.writestr('padding',b'0'*210000)
            self.assertTrue(any('compiled Android resources' in x for x in android.check(p)))
    def test_workflow_reports_failure_logs_and_package_identity(self):
        y=(ROOT/'.github/workflows/godot-checks.yml').read_text()
        self.assertIn('python3 release/verify_project_upload.py',y)
        self.assertIn('godot-validation-logs',y)
        self.assertIn('godot-android-build-logs',y)
        self.assertIn('android.permission.INTERNET',y)
        self.assertIn('com.iroaa15.gaminghub',y)
        self.assertIn("grep -q 'GODOT_SMOKE_PASS'",y)
    def test_smoke_uses_actual_supported_audience(self):
        s=(ROOT/'tests/godot_smoke.gd').read_text()
        self.assertNotIn('select_audience("adults")',s)
        self.assertIn('identical secret cards',s)
        self.assertIn('Player candidate list contains opponent secret',s)

if __name__=='__main__': unittest.main()
