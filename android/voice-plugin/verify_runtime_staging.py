#!/usr/bin/env python3
"""Check that a staged native voice distribution includes WebRTC runtime code.

This gate is deliberately separate from the published Godot Android APK.
"""
import io
import sys
import zipfile
from pathlib import Path

def contains_class(archive: Path, target: str) -> bool:
    with zipfile.ZipFile(archive) as aar:
        if target in aar.namelist():
            return True
        if "classes.jar" not in aar.namelist():
            return False
        with zipfile.ZipFile(io.BytesIO(aar.read("classes.jar"))) as jar:
            return target in jar.namelist()

def main(folder: Path) -> None:
    files = list(folder.glob("*.aar"))
    if not files:
        raise SystemExit("No AAR files staged")
    plugin_class = "com/iroaa15/gaminghub/voice/GamingHubVoicePlugin.class"
    rtc_class = "org/webrtc/PeerConnectionFactory.class"
    plugin = [p for p in files if contains_class(p, plugin_class)]
    rtc = [p for p in files if contains_class(p, rtc_class)]
    if len(plugin) != 1:
        raise SystemExit(f"Expected one Godot voice plugin AAR, found {len(plugin)}")
    if not rtc:
        raise SystemExit("Missing WebRTC runtime PeerConnectionFactory.class")
    print("VOICE_RUNTIME_STAGING_PASS")
    print(f"Plugin: {plugin[0].name}")
    print("WebRTC runtime: " + ", ".join(p.name for p in rtc))
    print("Not an integrated APK; device audio is not validated.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_runtime_staging.py <staging-directory>")
    main(Path(sys.argv[1]))
