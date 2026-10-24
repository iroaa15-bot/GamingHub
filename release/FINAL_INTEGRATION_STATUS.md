# Gaming Hub final integration — controlled staging

**Source:** `main` → release stabilization → `integration/gaminghub-final-20261024`.
**Do not merge to main, deploy server or publish Play yet.**

## Integrated into this branch
- Photo Duel standalone competitive screen and configurable two-player local prototype (editor-only).
- Isolated Python authoritative turn/score/question state machine and unit tests.
- Manually-triggered test workflow (not an Android build and not triggered on push).

## Deliberately not integrated yet
- 200 local image files and catalog: not present in GitHub. 102 further images require licensing review.
- Photo Duel entry in production home screen (blocked until image data and networking validated).
- Online Photo Duel server websocket routing (experimental code not copied to production).
- New Android voice native plugin and signaling modifications (not proven working on physical devices).
- Android release export, signed APK/AAB, AdMob production settings, Play upload.

## Release gates
1. Audit exact 200-image catalog and licenses; add approved assets through review without disclosing secrets.
2. Validate existing voice on Android with mic permission/onMainResume, room join, reconnect and logcat.
3. Integrate new feature through opt-in routing; server-side facts and image identity protection.
4. Build APK and AAB with reproducible SHA-256, test on two real Android devices.
5. Verify ad consent/age gating and test ad units, then Google Play testing track.
6. Only then open non-draft merge request for explicit approval.

No PASS/FAIL test result claimed before CI or physical device testing.
