extends SceneTree
class Picker:
 extends RefCounted
 signal avatar_result(image: String,error: String)
 var calls := 0
 func pickAvatar() -> void:calls+=1
class Account:
 extends "res://scripts/network/gaminghub_auth.gd"
 func _ready() -> void:pass
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.get_node("PublishedContent").busy=true
 root.get_node("RoomAudioPolicy").set_music_enabled(false)
 root.get_node("RoomAudioPolicy").set_effects_enabled(false)
 var account:=Account.new();root.add_child(account)
 var picker:=Picker.new();account.secure_store=picker
 assert(not account.choose_avatar())
 account.access_token="test-in-memory-only"
 assert(account.choose_avatar())
 assert(not account.choose_avatar())
 await process_frame
 assert(picker.calls==1)
 account._on_avatar_result("","cancelled")
 assert(not account.avatar_busy)
 assert(account.choose_avatar())
 await process_frame
 assert(picker.calls==2)
 account._on_avatar_result("","cancelled")
 account.queue_free();await process_frame
 print("AVATAR_PICKER_DISPATCH_PASS")
 quit(0)
