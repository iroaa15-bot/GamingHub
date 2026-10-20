from pathlib import Path
import hashlib
import json
import unittest
ROOT=Path(__file__).resolve().parents[1]
class RecoveryPreservation(unittest.TestCase):
    def test_original_content_and_services_unchanged(self):
        expected=json.loads((ROOT/'docs/recovery/baseline-preservation.json').read_text())
        for path,digest in expected['sha256'].items():
            with self.subTest(path=path):
                self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),digest)
