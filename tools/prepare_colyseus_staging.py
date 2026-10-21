#!/usr/bin/env python3
"""Prepare a separate Godot staging export without changing production sources.

Usage:
    python tools/prepare_colyseus_staging.py --output /tmp/gaminghub-voice-staging
    godot --headless --path /tmp/gaminghub-voice-staging --editor --import --quit
    godot --headless --path /tmp/gaminghub-voice-staging --export-debug "Android" /tmp/gaminghub-voice-staging.apk

The APK export requires local Android SDK, Godot export templates and signing setup.
This script intentionally does NOT build or publish an APK.
"""
import argparse
import json
import shutil
from pathlib import Path

STAGING_URL = "wss://gaminghub-voice-staging.onrender.com"
SKIP_DIRS = {".git", ".godot", ".gradle", ".idea", ".venv", "__pycache__", "build", "node_modules"}
SKIP_FILES = {".DS_Store"}


def prepare(source: Path, destination: Path) -> Path:
    source = source.resolve()
    destination = destination.resolve()
    if destination == source or source in destination.parents or destination in source.parents:
        raise ValueError("Staging destination must be outside the source tree")
    if destination.exists():
        raise FileExistsError(f"Refusing to overwrite: {destination}")
    network = json.loads((source / "data/network_config.json").read_text(encoding="utf-8"))
    production_url = network["server_url"]
    if production_url == STAGING_URL:
        raise ValueError("Production configuration already points to staging")
    shutil.copytree(
        source, destination,
        ignore=lambda _dir, names: [
            n for n in names
            if n in SKIP_FILES or (n in SKIP_DIRS and (Path(_dir) / n).is_dir())
        ],
    )
    # Explicit QA runner; it never replaces Main or executes on normal startup.
    diagnostics = destination / "diagnostics"
    diagnostics.mkdir(exist_ok=True)
    shutil.copyfile(source / "tests/android_voice_runtime.gd", diagnostics / "android_voice_runtime.gd")
    shutil.copyfile(source / "tests/recovery_runtime.gd", diagnostics / "recovery_runtime.gd")
    # Version-specific ID preserves both production and the old test app/data: its debug signing key is unavailable.
    presets_path = destination / "export_presets.cfg"
    presets = presets_path.read_text(encoding="utf-8")
    original_id = 'package/unique_name="com.iroaa15.gaminghub"'
    if presets.count(original_id) != 2:
        raise ValueError("Unexpected Android export presets; refusing unsafe staging export")
    presets = presets.replace(original_id, 'package/unique_name="com.iroaa15.gaminghub.colyseustest.voicefix118"')
    presets = presets.replace('package/name="Gaming Hub"', 'package/name="Gaming Hub Voice Test 11.8"')
    # Keep 32-bit Android phones eligible for this isolated device test.
    presets = presets.replace('architectures/armeabi-v7a=false', 'architectures/armeabi-v7a=true')
    presets = presets.replace('architectures/x86_64=false', 'architectures/x86_64=true')
    presets = presets.replace('version/code=117', 'version/code=118')
    presets = presets.replace('version/name="11.7"', 'version/name="11.8-test"')
    # Compress native libraries for an easier download and legacy Android loading.
    presets = presets.replace('gradle_build/use_gradle_build=true',
                              'gradle_build/use_gradle_build=true\ngradle_build/compress_native_libraries=true')
    presets = presets.replace('build/GamingHub-debug.apk', 'build/GamingHub-voice-staging-debug.apk')
    presets = presets.replace('build/GamingHub-release.aab', 'build/GamingHub-voice-staging-release.aab')
    presets_path.write_text(presets, encoding="utf-8")
    assert 'package/unique_name="com.iroaa15.gaminghub"' not in presets
    config = destination / "data/voice_staging.json"
    config.write_text(json.dumps({
        "enabled": True,
        "server_url": STAGING_URL,
    }, indent=2) + "\n", encoding="utf-8")
    # Daily autoloads have independent HTTP endpoints. Isolate those too, so
    # opening the test APK cannot make daily-content requests to production.
    for filename in ("live_ops.gd", "daily_ai.gd", "daily_rounds.gd"):
        path = destination / "scripts" / filename
        text = path.read_text(encoding="utf-8")
        original = "https://gaminghub-multiplayer.onrender.com"
        if text.count(original) != 1:
            raise ValueError(f"Unexpected daily endpoint in {filename}")
        path.write_text(text.replace(original, "https://gaminghub-voice-staging.onrender.com"), encoding="utf-8")
    copied_network = dict(network, server_url=STAGING_URL, note="Isolated Android test; production configuration is preserved in the source repository.")
    (destination / "data/network_config.json").write_text(json.dumps(copied_network, indent=2) + "\n", encoding="utf-8")
    assert json.loads((source / "data/network_config.json").read_text(encoding="utf-8"))["server_url"] == production_url
    assert json.loads(config.read_text(encoding="utf-8"))["server_url"] == STAGING_URL
    print(f"STAGING_PREPARED: {destination}")
    print(f"Production endpoint preserved: {production_url}")
    print(f"Staging endpoint: {STAGING_URL}")
    print("Staging Android package: com.iroaa15.gaminghub.colyseustest.voicefix118")
    return destination


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    prepare(Path(__file__).resolve().parents[1], args.output)


if __name__ == "__main__":
    main()
