import importlib.util, json, tempfile, unittest, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def module(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    obj=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj

manifest=module(ROOT/'release/source_manifest.py','source_manifest_v91')

class SourceSyncV91(unittest.TestCase):
    def test_project_manifest_matches(self):
        self.assertEqual([],manifest.verify(ROOT))
    def test_manifest_has_all_critical_files(self):
        data=json.loads((ROOT/'release/source_manifest.json').read_text())
        self.assertGreaterEqual(data['file_count'],150)
        for path in ['project.godot','scripts/main.gd','scripts/multiplayer.gd',
                     'scenes/Main.tscn','assets/ui/gaming_hub_icon.png',
                     'server/server.py','release/sync_to_github.py']:
            self.assertIn(path,data['sha256'])
    def test_modified_file_detected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            shutil.copytree(ROOT/'release',root/'release')
            (root/'project.godot').write_text('tampered')
            problems=manifest.verify(root)
            self.assertTrue(any('Modified source file: project.godot' in x for x in problems))
    def test_deleted_file_detected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            shutil.copytree(ROOT/'release',root/'release')
            problems=manifest.verify(root)
            self.assertTrue(any('Missing source file: scripts/main.gd' in x for x in problems))
    def test_extra_file_detected(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            shutil.copytree(ROOT/'release',root/'release')
            (root/'project.godot').write_bytes((ROOT/'project.godot').read_bytes())
            (root/'scripts').mkdir()
            (root/'scripts/unknown.gd').write_text('extends Node')
            self.assertTrue(any('Untracked source file: scripts/unknown.gd' in x for x in manifest.verify(root)))
    def test_publish_is_opt_in(self):
        s=(ROOT/'release/sync_to_github.py').read_text()
        self.assertIn("parser.add_argument('--publish',action='store_true'",s)
        self.assertIn("command('git','checkout','-b',branch",s)
        self.assertNotIn('git push --force',s)
    def test_ci_checks_manifest(self):
        s=(ROOT/'.github/workflows/godot-checks.yml').read_text()
        self.assertIn('python3 release/source_manifest.py',s)
        self.assertIn('v11.5-debug.apk',s)

if __name__=='__main__':unittest.main()
