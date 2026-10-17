#!/usr/bin/env python3
"""Validate that a compiled Android voice AAR contains required classes."""
import io
import sys
import zipfile
from pathlib import Path

def main(path: Path) -> None:
    if not path.is_file():
        raise SystemExit(f"Missing Android library: {path}")
    with zipfile.ZipFile(path) as aar:
        entries = set(aar.namelist())
        for name in ("AndroidManifest.xml", "classes.jar"):
            if name not in entries:
                raise SystemExit(f"Missing AAR entry: {name}")
        with zipfile.ZipFile(io.BytesIO(aar.read("classes.jar"))) as jar:
            classes = set(jar.namelist())
            for name in (
                "com/iroaa15/gaminghub/voice/GamingHubVoicePlugin.class",
                "com/iroaa15/gaminghub/voice/VoicePeer.class",
            ):
                if name not in classes:
                    raise SystemExit(f"Missing compiled class: {name}")
    print("VOICE_AAR_STRUCTURE_PASS")
    print("Runtime WebRTC dependencies still require Android app integration.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_aar.py <path-to-aar>")
    main(Path(sys.argv[1]))
