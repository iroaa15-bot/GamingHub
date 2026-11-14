extends SceneTree
class FakeNative extends Node:
 signal microphone_permission(granted: bool)
 signal voice_status(state: String,ticket: int,details: String)
 func getVoiceApiVersion() -> int: return 2
class RejectingBridge extends Node:
 signal voice_unavailable(reason: String)
 var calls:=0
 func set_consent(_a: bool,_b: bool) -> void:
  calls+=1
  voice_unavailable.emit("incompatible boundary")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var bridge=load("res://scripts/android_voice_integration_bridge.gd").new()
 var native=FakeNative.new()
 root.add_child(native)
 root.add_child(bridge)
 bridge.attach_native(native)
 var attached: bool=bridge.native_voice_bridge==native
 var adapter=load("res://scripts/photo_duel_voice_adapter.gd").new()
 var failing=RejectingBridge.new()
 root.add_child(adapter)
 root.add_child(failing)
 adapter.bridge=failing
 failing.voice_unavailable.connect(adapter._failure)
 adapter._failure("initial failure")
 var bounded: bool=failing.calls==1 and not adapter._handling_failure
 print("ANDROID_VOICE_BOUNDARY_REGRESSION ",attached," ",bounded)
 bridge.free()
 adapter.free()
 failing.free()
 native.free()
 quit(0 if attached and bounded else 1)
