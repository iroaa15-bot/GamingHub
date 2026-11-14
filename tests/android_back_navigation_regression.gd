extends SceneTree
class RoomProbe extends "res://scripts/multiplayer.gd":
 var back_calls:=0
 func _ready() -> void: pass
 func _request_exit_to_games() -> void: back_calls+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var room=RoomProbe.new()
 root.add_child(room)
 room._queue_room_back()
 room.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 await process_frame
 var room_ok: bool=room.back_calls==1
 var duel=load("res://scripts/photo_duel_extension_ui.gd").new()
 duel._home()
 var detached_ok: bool=not duel._leaving_scene
 print("ANDROID_BACK_REGRESSION ",room_ok," ",detached_ok)
 room.free()
 duel.free()
 quit(0 if room_ok and detached_ok else 1)
