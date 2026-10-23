# Gaming Hub — Voice-to-Production Integration Plan
Status: PLANNING / NOT DEPLOYED
Date: 2026-10-23
Branch: integration/voice-production-prep
Reference working voice branch: release/voice-safe-integration (c3f7c77)
Local compatibility-test commit: 5388f99

## Verified facts
- GitHub comparison main..release/voice-safe-integration: 33 changed files; voice branch is 2 commits ahead and 0 behind main at review time.
- The working Android voice APK was tested on two devices (clear bidirectional audio, no echo, stable connection and reconnection); keep that artifact unchanged.
- Existing server tests: 33 passed. One extra local legacy/v2 audio compatibility test passed (34 total).
- Main Android package ID: com.iroaa15.gaminghub; voice-test package ID: com.iroaa15.gaminghub.voicetest.
- Main server URL: wss://gaminghub-multiplayer.onrender.com; voice-test URL: wss://gaminghub-voice-staging.onrender.com.
- Main export lacks record_audio/modify_audio_settings permissions; voice-test export includes them.
- New client requires protocol=2 and a matching voice epoch for voice traffic. Do not point it at the older production server without a compatible server rollout.
- Production service has auto-deploy tied to main. Do not push or merge main without explicit approval.
- Integration branch was pushed to GitHub; local uncommitted configuration changes and other preexisting untracked/modified files are not included in the pushed commit.

## Integration boundaries
1. Preserve all existing gameplay, rooms, text chat, content generation, and AdMob configuration. No unrelated redesign during the voice merge.
2. Keep native/android-voice and addons/gaminghub_voice, plus scripts/android_voice_bridge.gd, from the verified voice implementation; do not rebuild or replace known-working AARs without cause.
3. Review scripts/main.gd, scripts/multiplayer.gd and project.godot as the client integration surface. Main and voice branch currently share ancestry; verify changes rather than blindly overwriting future main work.
4. Configure the release package as com.iroaa15.gaminghub, add microphone/audio settings permissions, preserve signing and other production export options. Increment version code before any Play upload (current preset 117).
5. Production config must point to production URL; never package a staging override in production builds. Confirm final exported resources.
6. The server needs a compatible, reversible rollout plan: test v2 and legacy clients against a staging instance running the candidate server, confirm consent reset, reconnect, room/gameplay and text behavior. Back up and plan rollback before any production change.
7. Deploy production server only with explicit authorization and after compatibility checks. Verify it is serving protocol 2; only then test production-connected client.
8. Produce an isolated test APK, check install/package, mic permission, voice between two phones without headset, rooms, chat, gameplay, reconnect and ads. Keep the original known-working APK intact.
9. After approval, prepare signed AAB and Google Play internal test; check AdMob test/live configuration, policy, privacy and Play Console status separately.
10. Only after integration passes, start UI/Party Room/new games work in a separate scoped branch.

## Do not do
- No automatic merge to main.
- No production Render changes or GitHub Actions builds without authorization.
- No git add ., git clean, git reset --hard, or blanket staging of pre-existing working-tree changes.
- No claim that 34 unit tests prove full end-to-end compatibility.

## Next execution gate
Prepare a narrowly scoped release-preset change on integration branch, preserving the production package ID and signing settings, with required audio permissions. Review diff before commit. Production server rollout remains blocked pending explicit approval.
