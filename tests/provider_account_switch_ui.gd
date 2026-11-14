extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var auth=root.get_node("GamingHubAccount")
 var saved_profile: Dictionary=auth.user_profile.duplicate(true)
 var saved_api: String=auth.api_base
 auth.api_base="";auth.user_profile={"providers":["google","facebook"]}
 var screen=load("res://scenes/AccountScreen.tscn").instantiate();root.add_child(screen)
 await process_frame
 for provider in ["google","facebook"]:screen.provider_buttons[provider].set_meta("provider_available",true)
 screen._busy(false)
 var valid: bool=not screen.provider_buttons.google.disabled and not screen.provider_buttons.facebook.disabled
 screen._busy(true)
 valid=valid and screen.provider_buttons.google.disabled and screen.provider_buttons.facebook.disabled
 screen.queue_free();await process_frame
 auth.user_profile=saved_profile;auth.api_base=saved_api
 print("PROVIDER_ACCOUNT_SWITCH_UI ",valid," existing provider does not prevent choosing another identity; busy blocks duplicate requests")
 quit(0 if valid else 1)
