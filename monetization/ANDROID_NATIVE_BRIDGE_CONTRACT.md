# Gaming Hub v10.4 — Android native adapter contract

This project does **not** bundle Google Mobile Ads SDK or UMP, and must remain in `disabled_prelaunch_no_sdk` until native integration and device verification.

## Required adapter behavior

- Godot Android plugin must expose `show_rewarded(request_id: int)` and emit `earned_reward(request_id: int, reward_type: String, amount: int)` **only** after Google Mobile Ads earned-reward callback.
- Native SDK must use **Google sample test ad unit IDs** for debug builds; never request live ads while testing.
- The plugin must initialize Google Mobile Ads and Google UMP on Android, resolve consent and privacy options, and surface failures. A consent decision alone is not sufficient: respect UMP `canRequestAds` and applicable child-directed restrictions.
- Disable all advertising for child/family profiles, as configured. No ad requests until audience and consent eligibility are confirmed.
- Reward IDs must be matched against the currently pending request; do not grant rewards on ad close, ad display, timeout or button click.
- Interstitial and banner remain OFF until UI placement, frequency capping, and applicable policies are verified.

## Blocking steps

1. Select and independently verify a maintained Godot 4.5 Android AdMob plugin and its UMP integration, including source code, version, license, Android Gradle compatibility, and Google Mobile Ads dependency.
2. Install Android build templates and plugin, add the AdMob App ID Android manifest metadata and required dependencies.
3. Implement callback adapter conforming to the signal/method contract above.
4. Run Android debug build with Google test IDs and inspect Logcat on a real device; verify rewarded success, failure, repeated callback, child profile and consent cases.
5. Complete Play Console policy declarations and AdMob app review before considering live ads.

No SDK or APK build is claimed in this release.
