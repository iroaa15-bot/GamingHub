# Android voice interruption fix — 14 November 2026

## Verified cause
On OPPO Android 9, SystemUI NotificationPlayer requested transient ducking at
22:39:44, followed by GamingHub `audio_focus_lost` at 22:39:45. The native listener
incorrectly treated every negative focus callback as a fatal interruption.

## Change
- Transient ducking reduces playback to 25%, then restores it on focus gain.
- Permanent loss and exclusive transient interruption still stop capture.
- Existing background/permission/consent teardown remains enforced.
- Software gain no longer amplifies quiet background frames immediately after speech.
- Debug diagnostics expose only audio effects/routing metadata, never speech or credentials.
- Restore the exact native source corresponding to the previous distributed AAR and
  verify both rebuilt variants against the reviewed source fingerprint in CI.

## Evidence and acceptance
- Recovered source fingerprint matched the previously shipped debug AAR before edits.
- Native JVM tests: 18 passed, including notification policy and noise-after-speech.
- Godot continuity and 14 consent/lifecycle checks passed using an isolated local data directory.
- OPPO speaker communication volume was 1/7; adjusted with volume keys to 4/7 in-call.
- OPPO AudioFlinger showed active AOSP AEC. This does not prove audible effectiveness.
- Updated APK installation, notification interruption and audible two-phone acceptance
  are pending. Previous APK audible acceptance failed (disconnect/echo/weak/noisy).

No server deploy, main change or production release is included.
