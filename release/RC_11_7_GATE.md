# Gaming Hub 11.7 — release candidate gates

This branch is cut **directly from main**. Do not merge experimental Photo Duel, Colyseus, or voice changes into it.

## Must pass before Google Play upload
- [ ] Confirm Android export templates, Android SDK, JDK, Gradle dependencies and signing credentials exist.
- [ ] Build **signed** APK for two-device smoke testing and signed release AAB; record SHA-256 and version code.
- [ ] Android launches without black screen for **Play with Friend** and **Play vs Computer**.
- [ ] Friends create/join rooms, gameplay, reconnection, and chat work on two physical phones.
- [ ] Android microphone permission + onMainResume tested; voice opt-in, mute, no-headset audio and disconnect/reconnect tested with logcat. If broken, block release or disable feature safely with explicit product decision.
- [ ] No regressions in existing games, assets/logo, daily content generation, servers and AdMob.
- [ ] Check test ads, age/consent handling, app-ads.txt, Play Data safety, content rating and store listing.
- [ ] Verify Play Console testing-track eligibility and any closed-testing requirements.
- [ ] Upload to internal/closed testing **only after** evidence passes; production release requires explicit go/no-go.

## Safety
- Main remains unchanged. No production deployment or live-server changes.
- No secret keys committed. No production ads during local testing.
- Do not trigger Actions/builds unless required and prerequisites are confirmed.
- Photo Duel remains isolated in its own feature branch.

Status: **BLOCKED pending Android build and real-device verification**. No APK/AAB or PASS claim yet.
