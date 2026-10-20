#!/usr/bin/env python3
"""Prepare a separate Godot staging export without changing production sources.

Usage:
    python tools/prepare_voice_staging.py --output /tmp/gaminghub-voice-staging
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
SKIP_DIRS = {".git", ".godot", ".gradle", ".idea", ".venv", "__pycache__", "build"}
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
    # Separate Android application ID prevents replacing the installed production app.
    presets_path = destination / "export_presets.cfg"
    presets = presets_path.read_text(encoding="utf-8")
    original_id = 'package/unique_name="com.iroaa15.gaminghub"'
    if presets.count(original_id) != 2:
        raise ValueError("Unexpected Android export presets; refusing unsafe staging export")
    presets = presets.replace(original_id, 'package/unique_name="com.iroaa15.gaminghub.recoverystaging"')
    presets = presets.replace('package/name="Gaming Hub"', 'package/name="Gaming Hub Recovery Test"')
    # Keep 32-bit Android phones eligible for this isolated device test.
    presets = presets.replace('architectures/armeabi-v7a=false', 'architectures/armeabi-v7a=true')
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
    copied_network = json.loads((destination / "data/network_config.json").read_text(encoding="utf-8"))
    assert copied_network["server_url"] == production_url
    assert json.loads(config.read_text(encoding="utf-8"))["server_url"] == STAGING_URL
    print(f"STAGING_PREPARED: {destination}")
    print(f"Production endpoint preserved: {production_url}")
    print(f"Staging endpoint: {STAGING_URL}")
    print("Staging Android package: com.iroaa15.gaminghub.recoverystaging")
    return destination


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    prepare(Path(__file__).resolve().parents[1], args.output)


if __name__ == "__main__":
    main()
