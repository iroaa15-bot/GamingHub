extends Node
## AdMob integration boundary. Requires a separately installed, reviewed Android SDK adapter.
## Never grant rewards based on button presses, timers, or an ad close event.
signal reward_earned(reward_type: String, amount: int)
signal ad_unavailable(reason: String)
signal reward_request_started(request_id: int)

var configuration: Dictionary = {}
var current_audience: String = ""
var native_adapter_ready := false
var ads_enabled := false
var consent_resolved := false
var consent_allows_ads := false
var pending_request_id := 0
var request_sequence := 0
var completed_request_ids: Dictionary = {}
var native_plugin: Object = null
var native_reward_signal_connected := false
var reward_request_in_flight := false

func _ready() -> void:
 var file := FileAccess.open("res://monetization/ad_config.json", FileAccess.READ)
 if file != null:
  var parsed: Variant = JSON.parse_string(file.get_as_text())
  if parsed is Dictionary:
   configuration = parsed
 # Fail closed on every launch until an audited native adapter explicitly initializes.
 native_adapter_ready = false
 ads_enabled = false
 # Wire only a native singleton with the explicit GamingHubAds contract.
 # No native singleton is included in this package; this never enables ads by itself.
 if OS.get_name() == "Android" and Engine.has_singleton("GamingHubAds"):
  var plugin: Object = Engine.get_singleton("GamingHubAds")
  attach_native_plugin(plugin)

func get_android_test_ids() -> Dictionary:
 # Test-only identifiers. Never use live IDs in development builds.
 return {
  "app": str(configuration.get("android_test_app_id", "")),
  "rewarded": str(configuration.get("android_test_rewarded_unit_id", "")),
  "interstitial": str(configuration.get("android_test_interstitial_unit_id", "")),
  "banner": str(configuration.get("android_test_banner_unit_id", ""))
 }

func attach_native_plugin(plugin: Object) -> bool:
 # Explicit dependency injection; no Android singleton is trusted by name alone.
 # The adapter must provide a dedicated earned-reward signal and a show method.
 if plugin == null or not plugin.has_signal("earned_reward") or not plugin.has_method("show_rewarded"):
  return false
 if native_plugin != null or plugin == self:
  return false
 native_plugin = plugin
 plugin.connect("earned_reward", Callable(self, "_on_native_reward"))
 native_reward_signal_connected = true
 return true

func _on_native_reward(request_id: int, reward_type: String, amount: int) -> void:
 if not native_reward_signal_connected or native_plugin == null:
  return
 confirm_native_reward(request_id, reward_type, amount)

func set_audience(value: String) -> void:
 if current_audience != value:
  cancel_pending_request()
  consent_resolved = false
  consent_allows_ads = false
  ads_enabled = false
 current_audience = value

func update_consent(resolved: bool, allows_ads: bool) -> void:
 # Call only after the native UMP flow reports the applicable consent state.
 consent_resolved = resolved
 consent_allows_ads = resolved and allows_ads
 if not consent_allows_ads:
  cancel_pending_request()
  ads_enabled = false
 else:
  ads_enabled = native_adapter_ready and configuration.get("mode", "") == "android_test_sdk"

func register_native_adapter(is_test_build: bool, sdk_initialized: bool) -> void:
 # Production integration must add an independently verified native bridge.
 native_adapter_ready = is_test_build and sdk_initialized and native_reward_signal_connected and native_plugin != null
 ads_enabled = native_adapter_ready and configuration.get("mode", "") == "android_test_sdk"

func is_ad_eligible() -> bool:
 return current_audience == "adults" and native_adapter_ready and ads_enabled and consent_resolved and consent_allows_ads

func request_rewarded_ad() -> void:
 if not is_ad_eligible():
  ad_unavailable.emit("Ads unavailable: audience, consent or native adapter not ready")
  return
 if pending_request_id != 0:
  ad_unavailable.emit("Rewarded ad request already in progress")
  return
 request_sequence += 1
 pending_request_id = request_sequence
 reward_request_in_flight = true
 reward_request_started.emit(pending_request_id)
 # The adapter must be independently reviewed before enabling android_test_sdk.
 if native_plugin == null or not native_plugin.has_method("show_rewarded"):
  cancel_pending_request()
  ad_unavailable.emit("Missing native rewarded bridge")
  return
 native_plugin.call("show_rewarded", pending_request_id)

func confirm_native_reward(request_id: int, reward_type: String, amount: int) -> void:
 # This method must only be called by a trusted native adapter's earned-reward callback.
 if not is_ad_eligible() or request_id <= 0 or request_id != pending_request_id:
  return
 if completed_request_ids.has(request_id) or reward_type != str(configuration.get("reward_currency", "Coins")) or amount != int(configuration.get("reward_amount", 50)):
  return
 completed_request_ids[request_id] = true
 pending_request_id = 0
 reward_request_in_flight = false
 reward_earned.emit(reward_type, amount)

func cancel_pending_request() -> void:
 pending_request_id = 0
 reward_request_in_flight = false

func report_rewarded_failed(request_id: int, reason: String) -> void:
 if request_id != pending_request_id or request_id == 0:
  return
 cancel_pending_request()
 ad_unavailable.emit(reason)

func request_interstitial_ad() -> void:
 # Interstitials remain disabled until frequency caps and placement review.
 return

func integration_diagnostics() -> Dictionary:
 # Read-only runtime diagnostics; never switch advertising on from this method.
 return {
  "sdk_present": native_plugin != null and native_reward_signal_connected,
  "sdk_initialized": native_adapter_ready,
  "consent_resolved": consent_resolved,
  "consent_allows_ads": consent_allows_ads,
  "audience_eligible": current_audience == "adults",
  "test_mode_enabled": configuration.get("mode", "") == "android_test_sdk",
  "production_ads_enabled": false,
  "reward_pending": pending_request_id != 0
 }

func status_text() -> String:
 if native_adapter_ready and ads_enabled:
  return "AdMob TEST SDK connected • earned-only rewards • production OFF"
 return "AdMob SDK missing or UMP unverified • ads disabled"
