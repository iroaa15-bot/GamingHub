"""Original assets, content, daily services and CI definitions must stay intact."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ColyseusPreservation(unittest.TestCase):
    def test_original_content_and_services_are_preserved(self):
        baseline = json.loads((ROOT/'docs/colyseus-recovery/preservation.json').read_text())
        for name, expected in baseline['sha256'].items():
            with self.subTest(file=name):
                self.assertEqual(expected, hashlib.sha256((ROOT/name).read_bytes()).hexdigest())

    def test_production_app_identity_and_endpoint_are_preserved_in_source(self):
        self.assertEqual('wss://gaminghub-multiplayer.onrender.com',
                         json.loads((ROOT/'data/network_config.json').read_text())['server_url'])
        self.assertEqual(2, (ROOT/'export_presets.cfg').read_text().count('package/unique_name="com.iroaa15.gaminghub"'))
