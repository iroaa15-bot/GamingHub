# Gaming Hub Android voice transport (development-only)

This directory is reserved for the Android native WebRTC plugin. The Godot client currently probes for the optional `GamingHubVoice` singleton and uses the following **proposed**, not-yet-implemented interface:

- Signal: `local_signal(Dictionary)` for SDP offers, answers and ICE candidates.
- Method: `receive_signal(String json)` to pass remote signaling to WebRTC.
- Method: `stop_call()` to stop capture, release tracks and close the peer connection.

**This interface alone is not a working voice transport.** A compatible Android Godot 4 plugin must be implemented, built and bundled with the Android export. It needs real microphone capture, audio track creation, peer connection lifecycle, playback, explicit mute/consent, Android runtime permission, STUN/TURN configuration and robust teardown.

Do not ship a placeholder plugin that reports successful calls without audio. The feature remains off by default (`GAMINGHUB_COMMS_ENABLED=false`) and the current audience policy does not expose voice controls.

## Implementation gates

1. Pin compatible Godot Android plugin APIs and a maintained WebRTC Android artifact; review licensing and binary provenance.
2. Implement native bridge and Android packaging in an isolated debug build; do not change the v11.7 release preset.
3. Require explicit in-match user activation, mutual voice consent and granted `RECORD_AUDIO` before opening the microphone.
4. Send `offer`/`answer`/`ice` only through the existing authenticated room signaling server. Stop tracks immediately on opt-out, block, hangup, disconnect or match exit.
5. Run Android device-to-device Wi-Fi/mobile data tests (including NAT/TURN), mute, denied permission and reconnection.
6. Review age gating, abuse reporting, moderation, data safety and Play policy before exposing to users.

No audio is recorded or stored by the existing signaling server.
