"""Regression tests for isolated staging export preparation (stdlib only)."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("prepare_voice_staging", ROOT / "tools/prepare_voice_staging.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class StagingPreparationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / "source"
        (self.source / "data").mkdir(parents=True)
        (self.source / "data/network_config.json").write_text(
            json.dumps({"server_url": "wss://gaminghub-multiplayer.onrender.com"}), encoding="utf-8"
        )
        (self.source / "export_presets.cfg").write_text(
            '\n'.join([
                '[preset.0]', 'package/unique_name="com.iroaa15.gaminghub"',
                'package/name="Gaming Hub"', 'export_path="build/GamingHub-debug.apk"',
                'architectures/arm64-v8a=true', 'architectures/armeabi-v7a=false',
                'gradle_build/use_gradle_build=true',
                '[preset.1]', 'package/unique_name="com.iroaa15.gaminghub"',
                'package/name="Gaming Hub"', 'export_path="build/GamingHub-release.aab"',
            ]), encoding="utf-8"
        )
        (self.source / "project.godot").write_text("config_version=5\n", encoding="utf-8")

    def test_staging_export_isolated(self):
        target = self.root / "isolated"
        MODULE.prepare(self.source, target)
        original = json.loads((self.source / "data/network_config.json").read_text())
        staged = json.loads((target / "data/network_config.json").read_text())
        override = json.loads((target / "data/voice_staging.json").read_text())
        self.assertEqual(original, staged)
        self.assertEqual(override["server_url"], MODULE.STAGING_URL)
        self.assertTrue(override["enabled"])
        presets = (target / "export_presets.cfg").read_text()
        self.assertEqual(presets.count('package/unique_name="com.iroaa15.gaminghub.voicestaging"'), 2)
        self.assertNotIn('package/unique_name="com.iroaa15.gaminghub"', presets)
        self.assertIn("Gaming Hub Voice Test", presets)
        self.assertIn("architectures/arm64-v8a=true", presets)
        self.assertIn("architectures/armeabi-v7a=true", presets)
        self.assertIn("gradle_build/compress_native_libraries=true", presets)
        self.assertNotIn("compress_native_libraries", (self.source / "export_presets.cfg").read_text())
        self.assertIn("architectures/armeabi-v7a=false", (self.source / "export_presets.cfg").read_text())
        self.assertFalse((self.source / "data/voice_staging.json").exists())

    def test_refuses_overwrite(self):
        target = self.root / "existing"
        target.mkdir()
        with self.assertRaises(FileExistsError):
            MODULE.prepare(self.source, target)

    def test_refuses_destination_inside_source(self):
        with self.assertRaises(ValueError):
            MODULE.prepare(self.source, self.source / "output")

    def test_refuses_staging_as_production(self):
        (self.source / "data/network_config.json").write_text(
            json.dumps({"server_url": MODULE.STAGING_URL}), encoding="utf-8"
        )
        with self.assertRaises(ValueError):
            MODULE.prepare(self.source, self.root / "isolated")

    def test_refuses_unexpected_export_preset(self):
        (self.source / "export_presets.cfg").write_text(
            'package/unique_name="com.iroaa15.gaminghub"', encoding="utf-8"
        )
        with self.assertRaises(ValueError):
            MODULE.prepare(self.source, self.root / "isolated")


if __name__ == "__main__":
    unittest.main()
