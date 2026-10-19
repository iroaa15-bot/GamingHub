extends SceneTree
## Two real multiplayer.gd clients + localhost Python server; simulated Android capture only.
var failures: Array[String] = []
var host: Control
var peer: Control
class FakeNative extends Node:
 signal microphone_permission(granted: bool)
 signal voice_status(state: String, ticket: int, details: String)
 var running := false
 var next_frame := 0
 var played := 0
 var last_sequence := -1
 var ordered := true
 var packet := ""
 func _init() -> void:
  var bytes := PackedByteArray()
  bytes.resize(640)
  for n in range(320): bytes.encode_s16(n * 2, int(4000 * sin(n * TAU * 440.0 / 16000.0)))
  packet = Marshalls.raw_to_base64(bytes)
 func getVoiceApiVersion() -> int: return 2
 func hasMicrophonePermission() -> bool: return true
 func requestMicrophonePermission() -> void: microphone_permission.emit(true)
 func startVoice(ticket: int) -> bool:
  running = true
  next_frame = Time.get_ticks_msec()
  last_sequence = -1
  voice_status.emit("started", ticket, "{\"simulated\":true}")
  return true
 func stopVoice() -> void: running = false
 func drainCapturedFrames() -> PackedStringArray:
  if running and Time.get_ticks_msec() >= next_frame:
   next_frame = Time.get_ticks_msec() + 20
   return PackedStringArray([packet])
  return PackedStringArray()
 func playVoiceFrame(pcm: String, sequence: int) -> bool:
  if not running: return false
  ordered = ordered and sequence > last_sequence and pcm == packet
  last_sequence = sequence
  played += 1
  return true

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
 host.android_voice_bridge.attach_native(a); peer.android_voice_bridge.attach_native(b)
 host.address_input.text = endpoint; peer.address_input.text = endpoint
 host._request_action({"type":"create"})
 if not await wait_until(func(): return not host.room_code.is_empty(), "host room creation"): finish(); return
 peer.code_input.text = host.room_code
 peer._join_room()
 if not await wait_until(func(): return host.player_index >= 0 and peer.player_index >= 0, "two Godot clients joined"): finish(); return
 check(peer.room_code == host.room_code and not peer.room_code.is_empty(), "joined client did not retain room identity")
 check(not host.voice_button.disabled and not peer.voice_button.disabled, "in-game voice button unavailable")
 host.set_voice_opt_in(true); peer.set_voice_opt_in(true)
 if not await wait_until(func(): return host.android_voice_bridge.active and peer.android_voice_bridge.active, "mutual consent did not activate voice"): finish(); return
 if not await wait_until(func(): return a.played >= 80 and b.played >= 80, "bidirectional PCM missing", 9000): finish(); return
 check(a.ordered and b.ordered, "PCM bytes or sequence changed in relay")
 var old_token: String = host.resume_token
 var old_epoch: int = host.voice_epoch
 host.socket.close()
 if not await wait_until(func(): return host.resume_token != old_token and host.connected and not host.reconnecting, "authenticated Godot reconnect failed", 15000): finish(); return
 check(not host.voice_requested and not peer.voice_requested, "reconnect retained consent")
 check(not a.running and not b.running, "reconnect retained microphone I/O")
 host.set_voice_opt_in(true); peer.set_voice_opt_in(true)
 if not await wait_until(func(): return host.android_voice_bridge.active and peer.android_voice_bridge.active, "voice did not restart after fresh consent"): finish(); return
 check(host.voice_epoch > old_epoch, "consent epoch did not advance")
 var before_a := a.played; var before_b := b.played
 await wait_until(func(): return a.played > before_a + 10 and b.played > before_b + 10, "no PCM after recovery")
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
  print("VOICE_ROOM_RUNTIME_PASS: two Godot clients, real WebSocket PCM, UI consent, room identity, disconnect/resume, new consent, leave")
  quit(0)
 else:
  for failure in failures: push_error(failure)
  quit(1)
