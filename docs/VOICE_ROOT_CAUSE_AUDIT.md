> Historical audit before the native implementation. See [current implementation and verified limits](ANDROID_VOICE_HANDOFF_AR.md).

# Gaming Hub — Voice root-cause audit (pre-APK)

## Verified in main
- `scripts/multiplayer.gd` uses `WebSocketPeer` for gameplay; no voice capture/playback or WebRTC client found in the tracked GDScript files.
- `server/server.py` relays `voice_audio` as 640-byte PCM16/16kHz/20ms Base64 frames over the room WebSocket and separately relays `voice_offer`, `voice_answer`, `voice_ice` signaling.
- `export_presets.cfg` enables INTERNET but does not enable RECORD_AUDIO in the Android presets.
- `server/test_voice_signaling.py` verifies signaling and packet admission, not device audio.
- TURN credentials are conditional on `GAMINGHUB_TURN_SECRET` and `GAMINGHUB_TURN_URLS`; empty credentials are possible.

## Blocking design decisions before any APK
1. Implement a real Android WebRTC audio client (native plugin/extension with verified packaging) with Opus, capture, playback, acoustic echo cancellation, noise suppression, and automatic gain control where supported. Do not assume Godot's signaling socket itself carries media.
2. Add Android RECORD_AUDIO manifest permission, runtime consent, and microphone privacy indicators; voice is strictly opt-in for both peers.
3. Keep room gameplay on existing WebSocket; use it only for WebRTC SDP/ICE signaling, not PCM media. Remove or explicitly disable the legacy PCM voice route once migration is verified.
4. Provide TURN over reachable UDP/TCP/TLS paths, short-lived credentials, ICE timeout and reconnect behavior. Never embed a permanent TURN secret in the client.
5. Specify single-owner voice state machine: IDLE -> REQUESTING_PERMISSION -> SIGNALING -> CONNECTING -> ACTIVE -> RECONNECTING -> STOPPED; idempotent teardown on leave, mute, background, disconnect, and consent revocation.
6. Verify Android communication audio mode, speakerphone routing, audio focus, Bluetooth route changes, mic ownership, sample-rate conversion, capture thread timing, and frame pacing.
7. Handle packet loss, jitter, duplicate/out-of-order signaling, ICE glare, ICE restarts, background/foreground, audio focus interruptions, and peer reconnect without breaking gameplay.
8. Provide explicit failure UX (permission denied, TURN unavailable, ICE failed, mic unavailable) without claiming voice connected.
9. Automated checks: signaling authorization, ICE state transitions, stale-session rejection, reconnect, opt-out teardown, protocol schema, permissions in export manifest, and simulated network faults. No APK until native plugin build and checks pass.
10. Final real-device verification remains necessary for acoustic echo performance; no simulation can guarantee device-specific speakerphone acoustics.

## Current status
Audit and safety branch only. No client voice implementation or real-device success is claimed. No APK/build workflow triggered.
