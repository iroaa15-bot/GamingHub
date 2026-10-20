extends SceneTree
var failures: Array[String] = []
class Native extends Node:
 signal microphone_permission(granted: bool)
 signal voice_status(state: String, ticket: int, details: String)
 signal voice_signal(kind: String, payload: String, ticket: int)
 var granted := true
 var started := 0
 var stopped := 0
 var received := 0
 var last_ticket := -1
 func getVoiceApiVersion() -> int: return 2
 func supportsWebRtcVoice() -> bool: return true
 func hasMicrophonePermission() -> bool: return granted
 func requestMicrophonePermission() -> void: microphone_permission.emit(granted)
 func startWebRtcVoice(ticket: int, caller: bool, _config: String) -> bool:
  started += 1; last_ticket = ticket
  voice_signal.emit("voice_offer" if caller else "voice_answer", "{\"sdp\":\"simulated\"}", ticket)
  voice_status.emit("started", ticket, "{\"simulated\":true,\"engine\":\"webrtc\"}")
  return true
 func receiveWebRtcSignal(_kind: String, _payload: String, _ticket: int) -> void: received += 1
 func stopVoice() -> void: stopped += 1
 func drainCapturedFrames() -> PackedStringArray:
  push_error("WebRTC must not poll PCM through Godot")
  return PackedStringArray()
func check(value: bool, message: String) -> void:
 if not value: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var bridge = load("res://scripts/android_voice_bridge.gd").new()
 var native := Native.new()
 root.add_child(native); root.add_child(bridge); bridge.attach_native(native)
 var signals: Array = []
 bridge.outgoing_signal.connect(func(kind: String, payload: Dictionary): signals.append([kind,payload]))
 bridge.configure_webrtc(true, {}); bridge.set_consent(true, false)
 check(native.started == 0, "one-sided consent started audio")
 bridge.set_consent(true, true)
 check(native.started == 1 and bridge.active and signals.size() == 1, "mutual consent/signaling failed")
 bridge.receive_signal("voice_ice", {"candidate":"candidate:test"})
 check(native.received == 1, "remote ICE missing")
 await process_frame
 bridge.set_consent(false, true)
 check(native.stopped == 1 and not bridge.active, "opt-out retained audio")
 native.voice_status.emit("started", native.last_ticket, "{}")
 native.voice_signal.emit("voice_offer", "{\"sdp\":\"late\"}", native.last_ticket)
 check(not bridge.active and signals.size() == 1, "stale callbacks revived audio")
 native.granted = false; bridge.set_consent(true, true)
 check(native.started == 1, "permission denial started audio")
 bridge.queue_free(); native.queue_free(); await process_frame
 if failures.is_empty():
  print("WEBRTC_BRIDGE_PASS: mutual consent, permission denial, signaling, no PCM polling, opt-out and stale callbacks; JNI simulated")
  quit(0)
 else:
  for failure in failures: push_error(failure)
  quit(1)
