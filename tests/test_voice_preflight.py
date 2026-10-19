"""Pre-APK static gate for the native Android voice migration.
Run locally: python -m unittest discover -s tests -p 'test_voice_preflight.py'
No GitHub Actions workflow is triggered by this test file.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class VoicePreflight(unittest.TestCase):
    def test_microphone_permission_on_both_presets(self):
        presets = (ROOT / 'export_presets.cfg').read_text(encoding='utf-8')
        sections = presets.split('[preset.')
        android = [s for s in sections if 'platform="Android"' in s]
        self.assertEqual(len(android), 2)
        for section in android:
            self.assertIn('permissions/record_audio=true', section)
            self.assertIn('permissions/internet=true', section)

    def test_server_requires_mutual_voice_consent(self):
        server = (ROOT / 'server/server.py').read_text(encoding='utf-8')
        self.assertIn('if not all(room.voice_enabled):', server)

    @unittest.expectedFailure
    def test_native_voice_client_must_be_implemented(self):
        """Intentional RED gate: do not mistake signaling for working media."""
        client = (ROOT / 'scripts/multiplayer.gd').read_text(encoding='utf-8')
        self.assertIn('native_voice_bridge', client)


if __name__ == '__main__':
    unittest.main()
