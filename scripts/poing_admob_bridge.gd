# Gaming Hub — Poing AdMob v5.1.0 bridge, activated ONLY after official add-on install.
# This is intentionally .template, not .gd, in the base project: without the
# Poing global classes Godot would fail import. Install script creates the .gd.
extends Node
signal earned_reward(request_id: int, reward_type: String, amount: int)

const UNIT_TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
var _init_done: bool = false
var _consent_started: bool = false
var _active_request: int = 0
var _shown_request_id: int = 0
var _reward_ad: RewardedAd
var _load_callback := RewardedAdLoadCallback.new()
var _full_callback := FullScreenContentCallback.new()
var _earn_listener := OnUserEarnedRewardListener.new()

func _ready() -> void:
 # No ad requests in desktop/editor, release build, or child/unknown profiles.
 if OS.get_name() != "Android" or not OS.has_feature("debug"):
  return
 if not Engine.has_singleton("PoingGodotAdMob") or not Engine.has_singleton("PoingGodotAdMobRewardedAd") or not Engine.has_singleton("PoingGodotAdMobConsentInformation"):
  return
 if not AdManager.attach_native_plugin(self):
  return
 _load_callback.on_ad_failed_to_load = _on_load_failure
 _load_callback.on_ad_loaded = _on_ad_loaded
 _full_callback.on_ad_dismissed_full_screen_content = _on_ad_closed
 _full_callback.on_ad_failed_to_show_full_screen_content = _on_ad_show_failed
 _earn_listener.on_user_earned_reward = _on_earned

func _process(_delta: float) -> void:
 if AdManager.current_audience != "adults" and _consent_started:
  _consent_started = false
  _init_done = false
  _active_request = 0
  _clear_ad()
  AdManager.update_consent(false, false)
 if _consent_started or AdManager.current_audience != "adults" or OS.get_name() != "Android" or not OS.has_feature("debug"):
  return
 if not Engine.has_singleton("PoingGodotAdMobConsentInformation"):
  return
 _consent_started = true
 var request := ConsentRequestParameters.new()
 request.tag_for_under_age_of_consent = false
 UserMessagingPlatform.consent_information.update(request, _on_consent_updated, _on_consent_error)

func _on_consent_updated() -> void:
 if AdManager.current_audience != "adults":
  return
 var info := UserMessagingPlatform.consent_information
 if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
  if info.get_is_consent_form_available():
   UserMessagingPlatform.load_consent_form(_on_form_loaded, _on_form_error)
  return
 _complete_ump()

func _on_form_loaded(form: ConsentForm) -> void:
 if AdManager.current_audience == "adults":
  form.show(_on_form_dismissed)

func _on_form_dismissed(_error: FormError) -> void:
 if _error != null:
  AdManager.update_consent(false, false)
  return
 _complete_ump()

func _on_consent_error(_error: FormError) -> void:
 AdManager.update_consent(false, false)

func _on_form_error(_error: FormError) -> void:
 AdManager.update_consent(false, false)

func _complete_ump() -> void:
 var status: int = UserMessagingPlatform.consent_information.get_consent_status()
 var allowed: bool = status == ConsentInformation.ConsentStatus.OBTAINED or status == ConsentInformation.ConsentStatus.NOT_REQUIRED
 if not allowed or AdManager.current_audience != "adults":
  AdManager.update_consent(false, false)
  return
 AdManager.update_consent(true, true)
 if _init_done:
  return
 var listener := OnInitializationCompleteListener.new()
 listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
  if AdManager.current_audience == "adults":
   _init_done = true
   AdManager.register_native_adapter(true, true)
 var config := RequestConfiguration.new()
 config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
 config.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
 config.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.FALSE
 MobileAds.set_request_configuration(config)
 MobileAds.initialize(listener)

func privacy_options_required() -> bool:
 return OS.get_name() == "Android" and AdManager.current_audience == "adults" and Engine.has_singleton("PoingGodotAdMobConsentInformation") and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

func show_privacy_options() -> void:
 if not privacy_options_required():
  return
 _active_request = 0
 _clear_ad()
 AdManager.update_consent(false, false)
 UserMessagingPlatform.show_privacy_options_form(_on_form_dismissed)

func show_rewarded(request_id: int) -> void:
 if request_id <= 0 or not _init_done or _active_request != 0 or not AdManager.is_ad_eligible():
  AdManager.report_rewarded_failed(request_id, "SDK / UMP not ready")
  return
 _active_request = request_id
 _clear_ad()
 var callback := RewardedAdLoadCallback.new()
 callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
  if request_id == _active_request:
   _on_load_failure(error)
 callback.on_ad_loaded = func(ad: RewardedAd) -> void:
  if request_id != _active_request:
   ad.destroy()
   return
  _on_ad_loaded(ad)
 RewardedAdLoader.new().load(UNIT_TEST_REWARDED, AdRequest.new(), callback)

func _on_ad_loaded(ad: RewardedAd) -> void:
 if _active_request == 0 or not AdManager.is_ad_eligible():
  ad.destroy()
  return
 _reward_ad = ad
 var shown_request: int = _active_request
 _shown_request_id = shown_request
 var full_callback := FullScreenContentCallback.new()
 full_callback.on_ad_dismissed_full_screen_content = func() -> void:
  if shown_request == _shown_request_id:
   _on_ad_closed()
 full_callback.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
  if shown_request == _active_request:
   _on_ad_show_failed(error)
 var earn_listener := OnUserEarnedRewardListener.new()
 earn_listener.on_user_earned_reward = func(item: RewardedItem) -> void:
  if shown_request == _active_request:
   _on_earned(item)
 _reward_ad.full_screen_content_callback = full_callback
 _reward_ad.show(earn_listener)

func _on_load_failure(error: LoadAdError) -> void:
 _fail("Failed to load test ad: " + error.message)

func _on_ad_show_failed(error: AdError) -> void:
 _fail("Failed to show test ad: " + error.message)

func _on_ad_closed() -> void:
 # Closing an ad NEVER grants coins.
 if _active_request != 0:
  _fail("Rewarded ad closed without earned callback")
 _clear_ad()

func _on_earned(_native_item: RewardedItem) -> void:
 # The native SDK callback alone grants the fixed in-game reward of 50 coins.
 if _active_request <= 0 or not AdManager.is_ad_eligible():
  return
 var accepted_request: int = _active_request
 _active_request = 0
 earned_reward.emit(accepted_request, "Coins", 50)

func _fail(reason: String) -> void:
 var id: int = _active_request
 _active_request = 0
 _clear_ad()
 if id > 0:
  AdManager.report_rewarded_failed(id, reason)

func _clear_ad() -> void:
 _shown_request_id = 0
 if _reward_ad != null:
  _reward_ad.destroy()
  _reward_ad = null

func _exit_tree() -> void:
 _clear_ad()
