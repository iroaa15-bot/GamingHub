"""Guard against regression where the exported source ZIP omits a test dependency."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

class UploadArchiveV93(unittest.TestCase):
 def test_archive_runner_validates_exact_zip(self):
  s=(ROOT/'release/verify_archive_runtime.py').read_text()
  self.assertIn('archive.extractall(root)',s)
  self.assertIn("'tests/run_checks.py'",s)
  self.assertIn("'release/verify_project_upload.py'",s)
 def test_campaign_regression_is_self_contained(self):
  s=(ROOT/'tests/test_release_v77.py').read_text()
  self.assertNotIn("(ROOT/'ASSET_OPTIMIZATION_v7.7.json')",s)
  self.assertIn("raw[8:12]==b'WEBP'",s)
 def test_ci_validates_same_archive(self):
  s=(ROOT/'.github/workflows/godot-checks.yml').read_text()
  self.assertIn('release/verify_archive_runtime.py /tmp/gaminghub-source.zip',s)
