# Gaming Hub v10.1 — native adapter contract

**Not a bundled SDK. Ads remain OFF.** This GDScript boundary requires a reviewed Godot 4.5 Android plugin backed by Google Mobile Ads and UMP.

Adapter interface: `signal earned_reward(request_id: int, reward_type: String, amount: int)` and `show_rewarded(request_id: int)`.

Do not expose an arbitrary game-script-accessible reward emitter in production. The native plugin must emit earned_reward only inside Google Mobile Ads `OnUserEarnedRewardListener`, match the pending request, and reject duplicate callbacks. For meaningful fraud resistance, validate reward server-side before crediting persistent currency; a client-only callback cannot guarantee integrity.

Native integration must implement UMP consent collection and privacy-options entry, platform age-appropriate treatment, load/show lifecycle, failure/close callbacks, Android manifest App ID, and test device configuration. Check Families policies before activating any ads; age self-selection alone is insufficient.

Test IDs only until device QA is complete. Never use live ads for development testing. The `mode` flag remains `disabled_prelaunch_no_sdk`; do not flip it without the plugin and policy review.
