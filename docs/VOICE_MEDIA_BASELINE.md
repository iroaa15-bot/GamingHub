# Gaming Hub voice media baseline

This branch is based on `work/voice-integration-validation`, which contains the Android voice invitation UI and consent ACK handlers; `main` does not yet include those client changes. Do not merge this entire branch into main without reviewing unrelated differences.

## Verified existing pieces
- Client `scripts/multiplayer.gd`: optional voice invitation dialog, `voice_state`, `voice_state_ack`, peer consent status.
- Server `main`: room-scoped `voice_state`, `voice_offer`, `voice_answer`, `voice_ice` signaling.
- No microphone capture, WebRTC audio media track, remote audio playback, or audio permission integration yet.
- Existing UI explicitly says audio is unavailable in the test build.

## Required implementation
1. Select an Android arm64 Godot 4.5.1 compatible native WebRTC audio media plugin; validate binaries and licensing. The Godot WebRTC data-channel implementation is NOT a substitute for media tracks.
2. Add microphone permission to Android export, request it only after both peers consent, handle denial and revoke.
3. Bridge SDP/ICE via existing authenticated room server; prevent stale session messages and cross-room leakage.
4. Add bidirectional audio tracks, audio focus, echo control, mute, and shutdown on leaving/background.
5. Run CI and real two-phone audio tests before changing the test-build warning or merging to main.

## Release safeguard
Keep the production main branch, current APK, and unrelated Gaming Hub features unchanged until tested. Other projects are out of scope.
