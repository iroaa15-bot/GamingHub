extends SceneTree
## Two real multiplayer.gd clients + localhost Python server; simulated Android capture only.
var failures: Array[String] = []
var host: Control
var peer: Control
class FakeNative extends Node:
 signal microphone_permission(granted: bool)
 signal voice_status(state: String, ticket: int, details: String)
 signal voice_signal(kind: String, payload: String, ticket: int)
 var running := false
 var granted := true
 var played := 0
 var ticket := 0
 var starts := 0
 func getVoiceApiVersion() -> int: return 2
 func supportsWebRtcVoice() -> bool: return true
 func hasMicrophonePermission() -> bool: return granted
 func requestMicrophonePermission() -> void: microphone_permission.emit(granted)
 func startWebRtcVoice(request: int, caller: bool, _config: String) -> bool:
  ticket = request; starts += 1
  if caller: voice_signal.emit("voice_offer", "{\"sdp\":\"simulated-offer\"}", ticket)
  return true
 func receiveWebRtcSignal(kind: String, _payload: String, _request: int) -> void:
  played += 1
  if kind == "voice_offer": voice_signal.emit("voice_answer", "{\"sdp\":\"simulated-answer\"}", ticket)
  if kind in ["voice_offer", "voice_answer"]:
   running = true
   voice_status.emit("started", ticket, "{\"simulated\":true,\"engine\":\"webrtc\"}")
 func stopVoice() -> void: running = false
 func drainCapturedFrames() -> PackedStringArray:
  push_error("WebRTC must not poll PCM on Godot")
  return PackedStringArray()

func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
func wait_until(predicate: Callable, message: String, timeout_ms: int = 7000) -> bool:
 var deadline := Time.get_ticks_msec() + timeout_ms
 while not predicate.call() and Time.get_ticks_msec() < deadline:
  await process_frame
 var passed: bool = predicate.call()
 check(passed, message)
 return passed
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var endpoint := OS.get_environment("GAMINGHUB_TEST_WS")
 if endpoint.is_empty():
  push_error("GAMINGHUB_TEST_WS must point to an isolated localhost test server")
  quit(2)
  return
 host = load("res://scripts/multiplayer.gd").new()
 peer = load("res://scripts/multiplayer.gd").new()
 root.add_child(host); root.add_child(peer)
 var a := FakeNative.new(); var b := FakeNative.new()
 root.add_child(a); root.add_child(b)
 host._setup_native_voice(); peer._setup_native_voice()
 host.android_voice_bridge.attach_native(a); peer.android_voice_bridge.attach_native(b)
 host.address_input.text = endpoint; peer.address_input.text = endpoint
 host._request_action({"type":"create"})
 if not await wait_until(func(): return not host.room_code.is_empty(), "host room creation"): finish(); return
 peer.code_input.text = host.room_code
 peer._join_room()
 if not await wait_until(func(): return host.player_index >= 0 and peer.player_index >= 0, "two Godot clients joined"): finish(); return
 check(peer.room_code == host.room_code and not peer.room_code.is_empty(), "joined client did not retain room identity")
 check(host._voice_room_ready() and peer._voice_room_ready(), "in-game voice room unavailable")
 check(host.android_voice_bridge.is_available() and peer.android_voice_bridge.is_available(), "test native boundary unavailable")
 if OS.get_name() == "Android":
  check(not host.voice_button.disabled and not peer.voice_button.disabled, "Android voice button unavailable")
 else:
  check(host.voice_button.disabled and peer.voice_button.disabled, "non-Android voice button should stay disabled")
 a.granted = false
 host.set_voice_opt_in(true)
 check(not host.voice_requested and not host.voice_desired and a.starts == 0, "denied microphone retained voice intent")
 a.granted = true
 host.set_voice_opt_in(true); peer.set_voice_opt_in(true)
 if not await wait_until(func(): return host.android_voice_bridge.active and peer.android_voice_bridge.active, "mutual consent did not activate voice"): finish(); return
 check(a.played >= 1 and b.played >= 1, "offer/answer missing")
 host.action_in_flight = true
 host._handle({"type":"error", "scope":"voice", "message":"test voice failure"})
 check(host.action_in_flight, "voice failure cancelled gameplay move")
 host.action_in_flight = false
 host.set_voice_opt_in(true)
 if not await wait_until(func(): return host.android_voice_bridge.active and peer.android_voice_bridge.active, "independent voice restart failed"): finish(); return
 var old_token: String = host.resume_token
 var old_epoch: int = host.voice_epoch
 host.socket.close()
 if not await wait_until(func(): return host.resume_token != old_token and host.connected and not host.reconnecting, "authenticated Godot reconnect failed", 15000): finish(); return
 if not await wait_until(func(): return host.android_voice_bridge.active and peer.android_voice_bridge.active, "automatic renewal of prior explicit consent failed", 10000): finish(); return
 check(host.voice_epoch > old_epoch, "consent epoch did not advance")
 check(a.starts >= 2 and b.starts >= 2, "WebRTC not recreated after recovery")
 host._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
 await wait_until(func(): return not host.android_voice_bridge.active, "background retained audio")
 check(host.voice_desired, "background forgot prior opt-in")
 host._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
 if not await wait_until(func(): return host.android_voice_bridge.active and peer.android_voice_bridge.active, "foreground restart failed"): finish(); return
 host.set_voice_opt_in(false)
 await wait_until(func(): return not host.android_voice_bridge.active and not peer.android_voice_bridge.active, "opt-out not propagated")
 check(not host.voice_desired, "opt-out retained restart intent")
 host._leave_match()
 await wait_until(func(): return host.room_code.is_empty() and peer.room_code.is_empty(), "room leave not propagated")
 check(not a.running and not b.running, "leave retained native audio")
 finish()
func finish() -> void:
 if is_instance_valid(host): host.queue_free()
 if is_instance_valid(peer): peer.queue_free()
 for node in root.get_children():
  if node is FakeNative: node.queue_free()
 await process_frame
 if failures.is_empty():
  print("WEBRTC_ROOM_RUNTIME_PASS: actual Godot clients/server signaling; JNI simulated; denial, voice error isolation, room recovery, background/foreground, opt-out and leave")
  quit(0)
 else:
  for failure in failures: push_error(failure)
  quit(1)
