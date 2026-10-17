# Gaming Hub v11.8 — Optional match communication (development only)

Branch: `feature/gaminghub-v11.8-optional-comms`. This branch is intentionally isolated from Google Play's current v11.7 closed test.

## Implemented in source
- Server-side per-match opt-in modes: `none`, `text`, `voice`, `both`.
- Chat relayed only to authenticated participants in the same active room, only when both opted in to text.
- Maximum 180 characters, 5 messages/15 seconds per sender, 30-message ephemeral room history.
- Block control shuts off communications for the remainder of the match.
- WebRTC offer/answer/ICE *signaling protocol* gated on mutual voice consent.
- Godot Arabic/English text chat UI for adult audience; defaults off, and both players must opt in.
- Voice choices deliberately disabled in the UI: signaling alone does NOT implement microphone capture, WebRTC peer connection, NAT traversal or TURN.

## Added in the next development step
- Added `server/test_optional_comms_v118.py` with seven local two-player WebSocket integration cases: consent, voice signaling, opt-out, block, limits, outsiders, and secret-safe snapshots.
- Server communications are disabled by default through `GAMINGHUB_COMMS_ENABLED=false`; tests temporarily enable the gate in process.
- Existing client audience state currently resolves to `all`, so the adult-only chat panel is intentionally not exposed until trustworthy age gating is designed.
- These tests are committed but **have not been executed or validated in CI** in this step.

## Required before any release
1. Integrate a working Godot Android WebRTC audio transport (with microphone runtime permission, push-to-talk/mute, both-player consent, STUN/TURN and reconnect cleanup); test on two real Android devices and mobile data/Wi-Fi.
2. Implement enforceable reporting/moderation workflow, abuse response, privacy retention rules, age-appropriate access restrictions and blocking for text/voice; current block control alone is insufficient for public release.
3. Add server and client automated tests (permissions, rate limits, cross-room isolation, disconnect/reconnect, regressions), Godot headless checks, APK builds and on-device QA.
4. Verify existing gameplay, AdMob, data safety and Play policy declarations after the feature.
5. Review/merge only after tests; do not deploy the development branch or replace v11.7 while closed testing is underway.

## Safety
No chat or voice is enabled in production v11.7 by this change. This is incomplete v11.8 development code, not a tested or installable release.
