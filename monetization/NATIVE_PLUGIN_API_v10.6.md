# GamingHubAds native Android plugin API

Godot Android plugin singleton name: `GamingHubAds`.

Required signal: `earned_reward(request_id: int, reward_type: String, amount: int)`
Required method: `show_rewarded(request_id: int)`

The Godot autoload now automatically discovers the singleton on Android and connects the earned-reward signal. This is a **real code connection point**, but it does not ship a Kotlin/AAR plugin or Google Mobile Ads SDK.

Native plugin must use Google rewarded callback `OnUserEarnedRewardListener`, never close callback, and must enforce Google UMP `canRequestAds`, child-directed policy, and Google sample test IDs.

On consent completion, trusted game code must call `AdManager.update_consent(resolved, can_request_ads)`; on native initialization `AdManager.register_native_adapter(true, true)` in a debug build only. Do not call either based on a fake timer or button.

Interstitial and banner remain disabled. Do not set android_test_sdk until the reviewed native plugin is installed and tested.
