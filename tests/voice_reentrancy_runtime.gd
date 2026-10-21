extends SceneTree
const Bridge = preload("res://scripts/android_voice_bridge.gd")
class IncompatibleNative extends Node:
 func getVoiceApiVersion() -> int: return 1
class RetryingBridge extends Bridge:
 var candidate: Object
 var attempts := 0
 func _try_attach_native() -> void:
  # Bound the old recursion so a regression fails without killing the runner.
  if native_voice_bridge == null and attempts < 8:
   attempts += 1
   attach_native(candidate)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game = load("res://scenes/Multiplayer.tscn").instantiate()
 root.add_child(game); current_scene = game
 await process_frame
 var candidate := IncompatibleNative.new(); root.add_child(candidate)
 var bridge := RetryingBridge.new(); bridge.candidate = candidate
 game.android_voice_bridge = bridge
 bridge.voice_unavailable.connect(game._on_voice_unavailable)
 bridge.status_changed.connect(game._on_voice_status)
 game.add_child(bridge)
 print("VOICE_REENTRANCY_ATTEMPTS=",bridge.attempts)
 var failed := bridge.attempts != 1
 var before := bridge.attempts
 for n in range(20): game._update_voice_ui()
 failed = failed or bridge.attempts != before or not is_instance_valid(game.create_button) or bridge.active
 game.queue_free(); candidate.queue_free(); await process_frame
 if failed: push_error("Voice failure reentered native attachment"); quit(1)
 else: print("VOICE_REENTRANCY_PASS: rejected plugin leaves game responsive; UI and opt-out do not initialize JNI"); quit(0)
