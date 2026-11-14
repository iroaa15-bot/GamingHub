extends SceneTree
class Boundary extends Node:
 signal microphone_permission(granted: bool)
 signal voice_status(state: String,ticket: int,details: String)
 var calls := 0
 var accept := true
 func getVoiceApiVersion() -> int: return 2
 func playVoiceFrame(_frame: String,_seq: int) -> bool:
  calls+=1
  return accept
 func stopVoice() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var bridge=load("res://scripts/android_voice_integration_bridge.gd").new()
 var native=Boundary.new()
 root.add_child(native);root.add_child(bridge)
 bridge.attach_native(native)
 bridge.active=true;bridge.local_opt_in=true;bridge.peer_opt_in=true
 bridge._health_capture("test-only")
 bridge.receive_pcm("test-only",1)
 native.accept=false
 bridge.receive_pcm("test-only",2)
 var data=bridge.voice_health_snapshot()
 var valid=data.captured_frames==1 and data.incoming_frames==2 and data.accepted_frames==1 and native.calls==2 and not JSON.stringify(data).contains("test-only")
 bridge.local_opt_in=false
 bridge.receive_pcm("test-only",3)
 valid=valid and native.calls==2
 print("VOICE_HEALTH_METADATA ",valid," — diagnostic boundary only, not audio quality or disconnect fix")
 bridge.active=false;bridge.starting=false
 bridge.queue_free();native.queue_free()
 await process_frame
 quit(0 if valid else 1)
