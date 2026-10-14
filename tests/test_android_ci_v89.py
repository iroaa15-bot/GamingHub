"""Static CI contract checks. Actual Godot and Android export run in GitHub Actions."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

class AndroidCIReadinessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = (ROOT/'.github/workflows/godot-checks.yml').read_text()
        cls.smoke = (ROOT/'tests/godot_smoke.gd').read_text()
        cls.project = (ROOT/'project.godot').read_text()

    def test_debug_job_requires_godot_validation(self):
        self.assertIn('android-debug:', self.workflow)
        self.assertIn('needs: validate', self.workflow)
        self.assertIn('include-templates: true', self.workflow)
        self.assertIn('godot --headless --path . --editor --import --quit', self.workflow)

    def test_debug_export_and_artifact(self):
        self.assertIn('--export-debug Android build/GamingHub-v11.5-debug.apk', self.workflow)
        self.assertIn('GamingHub-v11.5-Android-Debug', self.workflow)
        self.assertIn('if-no-files-found: error', self.workflow)

    def test_android_sdk_and_signature_checks(self):
        for token in ('setup-java@v4', "java-version: '17'", 'android-actions/setup-android@v3',
                      'platforms;android-36', 'build-tools;36.0.0', 'apksigner', 'aapt', 'editor_settings-4.5.tres', 'export/android/android_sdk_path', 'export/android/java_sdk_path'):
            self.assertIn(token, self.workflow)

    def test_debug_key_not_shipped_with_project(self):
        self.assertIn('keytool -genkeypair', self.workflow)
        self.assertNotIn('--export-release', self.workflow)
        self.assertFalse(list(ROOT.rglob('*.keystore')))
        self.assertFalse(list(ROOT.rglob('*.jks')))

    def test_headless_smoke_includes_offline_round(self):
        self.assertIn('_check_offline_picture_round()', self.smoke)
        self.assertIn('hub.start_game()', self.smoke)
        self.assertIn('hub.rival_secret.is_empty()', self.smoke)
        self.assertIn('res://scenes/Multiplayer.tscn', self.smoke)

    def test_android_config_and_scripts(self):
        presets=(ROOT/'export_presets.cfg').read_text()
        self.assertIn('package/unique_name="com.iroaa15.gaminghub"', presets)
        self.assertIn('permissions/internet=true', presets)
        self.assertIn('config/name="Gaming Hub"', self.project)
        for script in ('release/build_android.sh','release/build_android.ps1'):
            self.assertIn('GamingHub-v11.5-debug.apk',(ROOT/script).read_text())

if __name__=='__main__': unittest.main()
