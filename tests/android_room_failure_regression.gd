extends SceneTree
class RejectingBridge extends Node:
 signal voice_unavailable(reason: String)
 var calls:=0
 func set_consent(_a: bool,_b: bool) -> void:
  calls+=1
  voice_unavailable.emit("incompatible boundary")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var room=load("res://scripts/multiplayer.gd").new()
 var bridge=RejectingBridge.new()
 room.android_voice_bridge=bridge
 bridge.voice_unavailable.connect(room._on_voice_unavailable)
 room._on_voice_unavailable("first failure")
 var ok: bool=bridge.calls==1 and not room._handling_voice_failure and not room.voice_requested
 print("LEGACY_ROOM_FAILURE_REENTRY_PASS ",ok)
 room.free()
 bridge.free()
 quit(0 if ok else 1)
