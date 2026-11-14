extends SceneTree

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 root.get_node("PublishedContent").busy=true
 var account=root.get_node("GamingHubAccount")
 account.access_token=""
 account.user_profile={"display_name":"Verified player","points":10,"is_guest":false}
 var ui=load("res://scripts/player_account_ui.gd").new()
 ui.language="en"
 ui.local_progress={"xp":25,"wins":2,"matches":3}
 root.add_child(ui)
 assert(ui._profile_name.text=="Verified player")
 assert(ui._server_points.visible and ui._server_points.text=="Account points: 10")
 # Legacy friends responses must not replace the canonical online identity.
 ui._result("/friends",{},true)
 assert(ui._profile_name.text=="Verified player")
 assert(ui.local_progress.xp==25 and account.user_profile.points==10)
 account._forget_session()
 assert(not ui._server_points.visible and ui._profile_name.text=="Guest")
 ui.queue_free()
 await process_frame
 print("PASS: verified profile survives legacy responses; local XP stays separate; logout removes online identity")
 quit()
