# Gaming Hub Android voice media implementation

Status: engineering design only; NOT a working audio feature. Do not merge as a voice release.

## Verified baseline

- Godot 4.5.1, Android arm64-v8a, minimum SDK 24, Gradle Android export.
- Server on Render already relays `voice_state`, `voice_offer`, `voice_answer`, `voice_ice` only after mutual consent.
- Existing Godot client implements consent UI and `voice_state` but no SDP/ICE media handling or microphone audio.
- `export_presets.cfg` does not currently request `RECORD_AUDIO`.

## Native media decision gate

Choose a maintained Godot 4.5.1-compatible Android native plugin or GDExtension that explicitly implements WebRTC **audio media tracks**, not merely WebRTC data channels. Confirm Android arm64 binary, runtime microphone permission, remote audio playout, audio focus, headset routing, and acoustic echo cancellation before integrating. Godot WebRTCPeerConnection signaling/data-channel support alone does not prove microphone voice chat works.

## Consent and transport state machine

`OFF` -> `INVITED` -> `MUTUAL_CONSENT` -> `MIC_PERMISSION` -> `NEGOTIATING` -> `CONNECTED` -> `MUTED`/`ENDED`.

- Default `OFF`; never initialize capture or request microphone access while off.
- On `voice_state_ack`, wait until both `enabled` flags are true, then request Android microphone permission on the local device.
- Permission denied: show localized explanation and send `voice_state=false`; keep gameplay usable.
- Deterministic offerer (room player 0) sends `voice_offer`; peer sends `voice_answer`; both exchange `voice_ice` through existing room server. Discard SDP/ICE unless the current room and consent session match.
- Revoke consent, leave room, disconnect, or app background: stop microphone capture and remote playback, close peer connection, clear ICE state. Resume only with fresh consent.
- Explicit mute toggles the local outbound audio track, not the room consent flag.
- Do not persist audio, SDP, ICE, or voice consent to analytics, logs, or storage.

## Network reliability

- STUN is useful but insufficient for restrictive NAT/mobile networks. Production reliability may require a TURN relay, whose bandwidth can incur cost.
- Validate TURN credentials and expiry; never embed long-lived TURN secrets in the APK.
- Show `connecting`, `connected`, `reconnecting`, `failed`, `muted` states; avoid displaying 'voice active' based on consent alone.

## Release gates

1. Native Android plugin builds for arm64 on GitHub Actions and Godot 4.5.1.
2. Two physical Android devices exchange intelligible two-way audio on Wi-Fi.
3. Two devices exchange audio across Wi-Fi/mobile networks, including NAT-restricted case with TURN.
4. Android microphone permission is requested only after mutual consent; denial does not break multiplayer.
5. Revocation, mute, disconnect, app background, and reconnection stop/restore tracks correctly.
6. Verify source manifest, Godot parse, multiplayer smoke, Android debug APK, and permissions in CI.
7. Only after gates 1-6 pass, replace the 'audio unavailable in test build' status and publish a new APK.
