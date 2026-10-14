# Gaming Hub v10.5 — AdMob safety hardening

Base: v10.4. This release improves the Godot-side rewarded-ad state machine, not the Android native SDK.

- Clears pending requests on native ad failures using matching request IDs.
- Resets pending state when a reward is confirmed or consent/audience changes.
- Refuses attaching the manager itself as an adapter.
- Preserves fail-closed startup, test-only settings and 50 Coins callback-only rewards.
- Interstitial and banner remain disabled.

**Not done:** No Android SDK/UMP plugin is bundled; no APK was built or tested on device. No claim of live AdMob integration.

**Next:** Obtain a reviewed Godot 4.5 Android plugin + UMP implementation, install Android build templates, connect callbacks, and test a debug APK on a real Android phone.
