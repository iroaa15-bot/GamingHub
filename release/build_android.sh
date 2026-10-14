#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT_BIN:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "ERROR: Godot 4.5.1 not found. Set GODOT_BIN to the executable." >&2
  exit 2
fi
if ! "$GODOT" --version | grep -q '4.5.1'; then
  echo "ERROR: This project targets Godot 4.5.1. Installed: $("$GODOT" --version)" >&2
  exit 2
fi
python3 release/verify_project_upload.py
python3 tests/run_checks.py
"$GODOT" --headless --path "$ROOT" --editor --import --quit
"$GODOT" --headless --path "$ROOT" --script res://tests/godot_smoke.gd
"$GODOT" --headless --path "$ROOT" --quit-after 60
mkdir -p build
# Godot requires install-android-build-template together with the export action.
template_args=()
if [[ ! -f android/.build_version ]]; then
  template_args=(--install-android-build-template)
fi
case "${1:-debug}" in
  debug)
    "$GODOT" --headless --path "$ROOT" "${template_args[@]}" --export-debug Android build/GamingHub-v11.5-debug.apk
    python3 release/verify_android_package.py build/GamingHub-v11.5-debug.apk
    echo "Debug APK created. Install and test on two devices before any release."
    ;;
  release)
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?Set a release keystore path first}"
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?Set release key alias first}"
    : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Set release key password first}"
    "$GODOT" --headless --path "$ROOT" "${template_args[@]}" --export-release "Android Release" build/GamingHub-v11.5-release.aab
    python3 release/verify_android_package.py build/GamingHub-v11.5-release.aab --release
    echo "AAB produced, but device tests and Google Play policy gates remain mandatory."
    ;;
  *) echo "Usage: $0 [debug|release]" >&2; exit 2;;
esac
