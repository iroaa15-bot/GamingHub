#!/usr/bin/env python3
"""Fail CI if the staged native voice runtime cannot support an Android APK."""
from pathlib import Path
from zipfile import ZipFile
import sys

def main(folder: Path) -> None:
    if not folder.is_dir():
        raise SystemExit(f"VOICE_RUNTIME_FAIL: missing staging directory {folder}")
    files = list(folder.iterdir())
    voice = [p for p in files if p.name == "voice-plugin-debug.aar"]
    if len(voice) != 1:
        raise SystemExit("VOICE_RUNTIME_FAIL: voice-plugin-debug.aar missing")
    web_rtc = []
    for p in files:
        if p.suffix != ".aar":
            continue
        with ZipFile(p) as z:
            names = set(z.namelist())
            if any(n.startswith("jni/arm64-v8a/") and n.endswith(".so") for n in names):
                web_rtc.append(p.name)
    if not web_rtc:
        raise SystemExit("VOICE_RUNTIME_FAIL: no staged AAR contains arm64-v8a native libraries")
    print("VOICE_RUNTIME_STAGE_PASS")
    print("Staged files:", ", ".join(sorted(p.name for p in files)))
    print("AARs containing arm64 native libraries:", ", ".join(web_rtc))
    print("This does not prove Godot APK integration or functional audio.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_runtime_stage.py <staging-directory>")
    main(Path(sys.argv[1]))
