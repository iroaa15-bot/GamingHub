extends SceneTree
class RestoreAccount:
 extends Node
 var access_token="test-only-memory"
 var refresh_token=""
 func profile() -> Dictionary:
  return {"ok":true,"data":{"user":{"local_progress":{"xp":337,"wins":3,"matches":3}}}}

func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.get_node("PublishedContent").busy=true
 var real=root.get_node("GamingHubAccount")
 real.requested_provider=""
 real.requested_action="login"
 var account=load("res://scenes/AccountScreen.tscn").instantiate()
 root.add_child(account)
 await process_frame
 assert(account.layout_direction==Control.LAYOUT_DIRECTION_RTL or account.language=="en")
 for property in account.get_property_list():assert(property.name not in ["server_field","SETTINGS_FILE"])
 for field in account.find_children("*","LineEdit",true,false):
  assert(not "https" in field.placeholder_text.to_lower() and not "server" in field.placeholder_text.to_lower())
 assert(account.password_field.secret and account.password_field.max_length==256)
 account.queue_free()
 await process_frame
 var ui=load("res://scripts/player_account_ui.gd").new()
 ui.language="en";ui.local_progress={"xp":25,"wins":0,"matches":0}
 root.add_child(ui)
 for property in ui.get_property_list():assert(property.name!="admin")
 var fake=RestoreAccount.new();root.add_child(fake);ui.online_account=fake
 await ui._restore_online_progress()
 assert(ui.local_progress.xp==337 and ui._level.text.contains("337") and ui._stats.text.contains("3 wins"))
 ui.queue_free();fake.queue_free()
 await process_frame
 var main=load("res://scenes/Main.tscn").instantiate()
 root.add_child(main)
 await process_frame
 main.age_group="18plus"
 main.reduced_motion=true
 main.show_home()
 var navigation=main.get_node("PlayerBottomNavigation")
 assert(navigation.get_child(0).get_child_count()==4)
 assert(main.root.get_node("UnifiedGameCatalog").get_child(0).get_meta("game_id")==0)
 main.show_player_friends()
 assert(main.get_node("PlayerBottomNavigation").get_child(0).get_child_count()==4)
 main.show_accessibility()
 assert(main.get_node("PlayerBottomNavigation").get_child(0).get_child_count()==4)
 var room=load("res://scenes/PhotoDuelLocal.tscn").instantiate()
 root.add_child(room)
 await process_frame
 assert(not room.get_property_list().any(func(value: Dictionary):return value.name=="endpoint_field"))
 room.queue_free();main.queue_free()
 await process_frame
 print("PLAYER_SAFE_ACCOUNT_PASS: no player endpoint/admin controls; protected password field; immediate restored progress display")
 quit()
