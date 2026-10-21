#!/usr/bin/env bash
# Build a fresh, isolated Android test APK from the reviewed experimental source.
# Never use GitHub Actions, production servers, or the main branch.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
EXPECTED_BRANCH="experiment/colyseus-room-poc"
ACTUAL_BRANCH="$(git branch --show-current)"
if [[ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]]; then
  echo "REFUSING: on '$ACTUAL_BRANCH', expected '$EXPECTED_BRANCH'." >&2
  exit 2
fi
for command in python3 java git mktemp sha256sum; do
  command -v "$command" >/dev/null || { echo "Missing: $command" >&2; exit 3; }
done
GODOT_BIN="${GODOT_BIN:-godot}"
command -v "$GODOT_BIN" >/dev/null || { echo "Missing Godot executable: $GODOT_BIN" >&2; exit 3; }
if [[ -z "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ]]; then
  echo "Missing Android SDK path (ANDROID_HOME or ANDROID_SDK_ROOT)." >&2
  exit 3
fi
if [[ ! -f native/android-voice/gradlew ]]; then
  echo "Missing pinned Gradle wrapper." >&2
  exit 3
fi
OUT_DIR="${1:-${TMPDIR:-/tmp}/gaminghub-voice-fix-output}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
if [[ "$OUT_DIR" == "$ROOT" || "$OUT_DIR" == "$ROOT/"* ]]; then
  echo "Output MUST be outside the source checkout." >&2
  exit 2
fi
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}"
echo "[1/6] Run native JVM tests and Android lint; rebuild both AARs"
(cd native/android-voice && bash ./gradlew --no-daemon --max-workers=2 testDebugUnitTest lintDebug lintRelease installPlugin)
echo "[2/6] Reject stale/missing Android plugin binaries"
python3 tools/verify_voice_aar.py
echo "[3/6] Create isolated staging source with different package/URLs"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/gaminghub-voice-fix.XXXXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
# prepare_colyseus_staging refuses existing destinations; place source in new child
python3 tools/prepare_colyseus_staging.py --output "$STAGING/source"
echo "[4/6] Import Godot resources"
"$GODOT_BIN" --headless --path "$STAGING/source" --editor --import --quit
echo "[5/6] Export the test APK (no production install/publish)"
APK="$OUT_DIR/GamingHub-Colyseus-Voice-Fix-Test.apk"
if [[ -e "$APK" ]]; then
  echo "REFUSING to overwrite existing $APK" >&2
  exit 2
fi
"$GODOT_BIN" --headless --path "$STAGING/source" --export-debug "Android" "$APK"
test -s "$APK" || { echo "APK not produced" >&2; exit 5; }
echo "[6/6] Verify Android package identity and fingerprint"
SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT}}"
AAPT_BIN="$(find "$SDK_ROOT/build-tools" -maxdepth 2 -type f -name aapt 2>/dev/null | sort -V | tail -1)"
if [[ -z "$AAPT_BIN" ]]; then
  echo "REFUSING: Android build-tools aapt is required to verify package identity." >&2
  exit 6
fi
"$AAPT_BIN" dump badging "$APK" | grep -F "package: name='com.iroaa15.gaminghub.colyseustest'" >/dev/null ||
  { echo "REFUSING: wrong Android package identity" >&2; exit 6; }
sha256sum "$APK" | tee "$OUT_DIR/GamingHub-Colyseus-Voice-Fix-Test.sha256"
echo "BUILT: $APK"
echo "Not device-tested. Reproduce both voice-button scenarios on actual Android hardware."
