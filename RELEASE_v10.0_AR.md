# Gaming Hub v10.0 — AdMob Integration Preparation

## Completed
- Registered the real Android App ID and three production ad-unit IDs in `monetization/ad_config.json`.
- Added Google sample **test-only** Banner ID alongside existing test Rewarded/Interstitial IDs.
- Kept ads OFF and the existing fail-closed reward guard intact.
- Set Rewarded design to 50 Coins, awarded **only** after the trusted SDK earned-reward callback; this is a design setting, not an active feature.
- Preserved gameplay, graphics, multiplayer and server files from v9.9.

## NOT completed — required before claiming ads work
- Install and verify a Godot 4.5-compatible Android plugin implementing Google Mobile Ads and Google's User Messaging Platform (UMP).
- Implement and audit the native-to-Godot bridge, callbacks, lifecycle, and reward state persistence.
- Configure Android export, manifest, consent and appropriate age/family treatment; test on a physical Android device.
- Add suitable banner/interstitial placements after gameplay review.
- Publish to a supported app store, link the store listing in AdMob, complete review and any required app-ads.txt verification.

## Important policy guard
Gaming Hub offers child and family experiences. Simply asking a user to select an age group does not establish a reliable age determination. No ads are enabled in this build for any audience. Assess the Google Play Families policy and AdMob child-directed requirements before activation.

## IDs
App: `ca-app-pub-7722018346088731~9358178867`
Rewarded: `ca-app-pub-7722018346088731/5504448353`
Interstitial: `ca-app-pub-7722018346088731/2785266661`
Banner: `ca-app-pub-7722018346088731/1182059961`

Do not click your own live ads. Do not switch `mode` to test or production merely by editing JSON.
