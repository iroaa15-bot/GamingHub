"""Packaging checks complement executable Godot/JVM/real-WebSocket tests."""
import configparser
from pathlib import Path
import unittest
from zipfile import ZipFile
ROOT = Path(__file__).resolve().parents[1]

class VoicePreflight(unittest.TestCase):
    def test_microphone_permission_on_both_presets(self):
        presets = configparser.ConfigParser()
        presets.read(ROOT/'export_presets.cfg')
        for variant in (0, 1):
            self.assertEqual(presets[f'preset.{variant}.options']['permissions/record_audio'], 'true')
            self.assertEqual(presets[f'preset.{variant}.options']['permissions/internet'], 'true')
    def test_server_requires_mutual_voice_consent(self):
        self.assertIn('if not all(room.voice_enabled):', (ROOT/'server/server.py').read_text())
    def test_native_distributables_register_the_godot_plugin(self):
        from tools.verify_voice_aar import verify
        for variant in ('debug', 'release'):
            verify(ROOT/f'addons/gaminghub_voice/bin/gaminghub-voice-{variant}.aar')
            with ZipFile(ROOT/f'addons/gaminghub_voice/bin/gaminghub-voice-{variant}.aar') as aar:
                manifest = aar.read('AndroidManifest.xml').decode()
                for text in ('org.godotengine.plugin.v2.GamingHubVoice',
                             'com.gaminghub.voice.GamingHubVoicePlugin',
                             'android.permission.RECORD_AUDIO', 'android.permission.MODIFY_AUDIO_SETTINGS'):
                    self.assertIn(text, manifest)
                import io
                with ZipFile(io.BytesIO(aar.read('classes.jar'))) as jar:
                    for name in ('GamingHubVoicePlugin', 'AndroidVoiceEngine', 'VoiceJitterBuffer', 'CapturedFrames'):
                        self.assertIn(f'com/gaminghub/voice/{name}.class', jar.namelist())
    def test_addon_is_enabled_and_native_source_is_archived(self):
        self.assertIn('res://addons/gaminghub_voice/plugin.cfg', (ROOT/'project.godot').read_text())
        import json
        manifest = json.loads((ROOT/'release/source_manifest.json').read_text())['sha256']
        for path in ('native/android-voice/build.gradle.kts', 'native/android-voice/gradlew',
                     'native/android-voice/src/main/java/com/gaminghub/voice/AndroidVoiceEngine.kt',
                     'scripts/android_voice_bridge.gd', 'tests/voice_runtime.gd'):
            self.assertIn(path, manifest)

if __name__ == '__main__': unittest.main()
