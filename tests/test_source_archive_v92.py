"""Tests for safe deterministic source release archives."""
import importlib.util
import io
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
import sys
sys.path.insert(0, str(ROOT/'release'))
from source_archive import build, verify_archive


class SourceArchiveV92(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.first = Path(cls.temp.name)/'first.zip'
        cls.second = Path(cls.temp.name)/'second.zip'
        cls.count, cls.size = build(cls.first, ROOT)
        build(cls.second, ROOT)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_source_is_reproducible(self):
        self.assertEqual(self.first.read_bytes(), self.second.read_bytes())

    def test_source_archive_verifies(self):
        self.assertEqual(self.count, verify_archive(self.first))
        self.assertGreater(self.count, 170)

    def test_critical_source_and_assets_present(self):
        with ZipFile(self.first) as z:
            for name in ['project.godot','export_presets.cfg',
                         'scripts/main.gd','scripts/multiplayer.gd',
                         'server/server.py','assets/ui/gaming_hub_icon.png',
                         '.github/workflows/godot-checks.yml']:
                self.assertIn(name, z.namelist())

    def test_no_credentials_or_build_outputs(self):
        with ZipFile(self.first) as z:
            for name in z.namelist():
                self.assertNotIn('__pycache__',name)
                self.assertFalse(name.endswith(('.pyc','.keystore','.jks','.p12')))
                self.assertNotIn('/.godot/', '/'+name)
                self.assertNotIn('/build/', '/'+name)

    def test_corrupted_source_detected(self):
        modified = Path(self.temp.name)/'tampered.zip'
        with ZipFile(self.first) as original, ZipFile(modified, 'w') as output:
            for name in original.namelist():
                payload = original.read(name)
                output.writestr(name, b'bad' if name=='project.godot' else payload)
        with self.assertRaisesRegex(ValueError,'checksum mismatch'):
            verify_archive(modified)

    def test_traversal_rejected(self):
        modified = Path(self.temp.name)/'unsafe.zip'
        with ZipFile(self.first) as original, ZipFile(modified,'w') as output:
            for name in original.namelist():
                output.writestr(name,original.read(name))
            output.writestr('../unsafe.txt', 'no')
        with self.assertRaisesRegex(ValueError,'Unsafe archive path'):
            verify_archive(modified)

    def test_missing_asset_detected(self):
        modified = Path(self.temp.name)/'missing.zip'
        with ZipFile(self.first) as original, ZipFile(modified,'w') as output:
            for name in original.namelist():
                if name != 'assets/ui/gaming_hub_icon.png':
                    output.writestr(name,original.read(name))
        with self.assertRaisesRegex(ValueError,'Archive contents differ'):
            verify_archive(modified)

if __name__=='__main__': unittest.main()
