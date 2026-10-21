extends SceneTree
# Exercises actual bridge and multiplayer code; the Android/JNI boundary is a fake.
var failures: Array[String] = []
var emitted: Array[String] = []
class FakeNative extends Node:
 signal microphone_permission(granted: bool)
 signal voice_status(state: String, ticket: int, details: String)
 var granted := false
 var starts: Array[int] = []
 var stops := 0
 var permission_requests := 0
 var frames: Array[String] = []
 var played: Array = []
 func getVoiceApiVersion() -> int: return 2
 func hasMicrophonePermission() -> bool: return granted
 func requestMicrophonePermission() -> void: permission_requests += 1
 func startVoice(ticket: int) -> bool:
  starts.append(ticket)
  return true
 func stopVoice() -> void: stops += 1
 func drainCapturedFrames() -> Array[String]:
  var out := frames.duplicate()
  frames.clear()
  return out
 func playVoiceFrame(pcm: String, seq: int) -> bool:
  played.append([pcm, seq])
  return true

func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var bridge = load("res://scripts/android_voice_bridge.gd").new()
 var native := FakeNative.new()
 root.add_child(native); root.add_child(bridge)
 bridge.attach_native(native)
 bridge.outgoing_pcm.connect(func(pcm: String): emitted.append(pcm))
 bridge.set_consent(true, false)
 check(native.starts.is_empty(), "one-sided consent started microphone")
 bridge.request_permission()
 check(native.permission_requests == 1, "permission was not requested")
 native.granted = true
 bridge.set_consent(true, true)
 check(native.starts.size() == 1 and bridge.starting and not bridge.active, "async start state")
 bridge.set_consent(true, true)
 check(native.starts.size() == 1, "duplicate start")
 var old_ticket: int = native.starts[0]
 bridge.set_consent(false, false)
 native.voice_status.emit("started", old_ticket, "{}")
 check(not bridge.active and native.stops == 1, "stale start survived opt-out")
 bridge.set_consent(true, true)
 native.voice_status.emit("started", native.starts[-1], "{}")
 native.frames.assign(["frame"])
 bridge._process(0)
 check(emitted == ["frame"], "native capture not forwarded")
 bridge.receive_pcm("peer", 4)
 check(native.played == [["peer", 4]], "peer PCM not played")
 native.voice_status.emit("suspended", -1, "focus lost")
 check(not bridge.active, "background did not stop audio")
 bridge.receive_pcm("late", 5)
 check(native.played.size() == 1, "audio played after suspension")
 bridge.queue_free(); native.queue_free()
 await process_frame
 var game = load("res://scripts/multiplayer.gd").new()
 root.add_child(game)
 await process_frame
 var game_native := FakeNative.new(); game_native.granted = true; root.add_child(game_native)
 game._setup_native_voice()
 game.android_voice_bridge.attach_native(game_native)
 game.connected = true; game.finished = false; game.room_code = "TEST01"; game.player_index = 0
 game.voice_requested = true
 game._handle({"type":"voice_state_ack", "protocol":2, "enabled":true, "peer_enabled":true, "epoch":10})
 check(game.voice_local_enabled and game.voice_peer_enabled, "server consent not consumed")
 game_native.voice_status.emit("started", game_native.starts[-1], "{}")
 game._handle({"type":"voice_audio", "player":1, "epoch":9, "seq":1, "pcm":"old"})
 game._handle({"type":"voice_audio", "player":0, "epoch":10, "seq":2, "pcm":"self"})
 game._handle({"type":"voice_audio", "player":1, "epoch":10, "seq":3, "pcm":"valid"})
 check(game_native.played == [["valid", 3]], "epoch/self filtering failed")
 game.action_in_flight = true
 game._handle({"type":"error", "scope":"voice", "message":"test"})
 check(game.action_in_flight, "voice error cancelled pending gameplay")
 check(not game.voice_local_enabled and not game.android_voice_bridge.active, "voice error did not stop audio")
 game._handle({"type":"voice_state_ack", "protocol":2, "enabled":true, "peer_enabled":true, "epoch":11})
 check(not game.android_voice_bridge.active, "late ack reopened opted-out mic")
 game.voice_requested = true
 game._handle({"type":"voice_state_ack", "protocol":2, "enabled":true, "peer_enabled":true, "epoch":12})
 game_native.voice_status.emit("started", game_native.starts[-1], "{}")
 game._handle({"type":"paused"})
 check(not game.voice_requested and not game.android_voice_bridge.active, "peer disconnect did not clear consent")
 game.queue_free(); game_native.queue_free()
 await process_frame
 if failures.is_empty():
  print("VOICE_RUNTIME_PASS: bridge lifecycle, permission, async state, native PCM boundary, consent, epochs, reconnect reset, gameplay isolation")
  quit(0)
 else:
  for failure in failures: push_error(failure)
  quit(1)
