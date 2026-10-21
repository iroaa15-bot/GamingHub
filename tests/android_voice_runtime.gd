extends SceneTree
# Explicit adb entry point, packaged only in the separate staging APK.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func run() -> void:
 if OS.get_name() != "Android": push_error("Android runtime required"); quit(2); return
 Engine.max_fps = 15 # Limit software-emulator rendering, only during this test.
 create_timer(180).timeout.connect(func(): push_error("ANDROID_VOICE_TIMEOUT"); quit(1))
 print("ANDROID_VOICE_RUNTIME_BEGIN")
 var game = load("res://scenes/Multiplayer.tscn").instantiate()
 root.add_child(game); current_scene = game
 await process_frame
 print("ANDROID_BEFORE_DIAGNOSTICS")
 game._show_voice_diagnostics()
 check(game.android_voice_bridge == null, "Diagnostics initialized native audio")
 print("ANDROID_AFTER_DIAGNOSTICS")
 for child in game.get_children():
  if child is AcceptDialog: child.queue_free()
 print("ANDROID_BEFORE_VOICE_BUTTON")
 game.voice_button.pressed.emit()
 print("ANDROID_AFTER_VOICE_BUTTON")
 check(game.android_voice_bridge != null, "Voice button did not create bridge")
 check(game.android_voice_bridge.is_available(), "Native bridge rejected")
 check(game.android_voice_bridge.uses_webrtc(), "WebRTC negotiation failed")
 check(Engine.has_singleton("GamingHubVoice"), "Plugin not registered")
 var native = Engine.get_singleton("GamingHubVoice")
 print("ANDROID_JNI_HAS_METHOD=",native.has_method("getVoiceApiVersion"))
 check(int(native.getVoiceApiVersion()) == 2, "JNI API call failed")
 if "--request-microphone" in OS.get_cmdline_user_args():
  var results: Array[bool] = []
  game.android_voice_bridge.permission_ready.connect(func(value: bool): results.append(value); print("ANDROID_PERMISSION_CALLBACK=",value))
  game.android_voice_bridge.request_permission()
  var deadline := Time.get_ticks_msec() + 90000
  while results.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
  check(not results.is_empty(), "Microphone callback missing")
 var granted: bool = native.hasMicrophonePermission()
 print("ANDROID_MIC_PERMISSION=",granted)
 var code := ""
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--room-code="): code = argument.trim_prefix("--room-code=")
 if not code.is_empty():
  check(granted, "Room voice test requires microphone permission")
  game.set_voice_opt_in(false)
  game.address_input.text = "ws://127.0.0.1:2568/gaminghub"
  game.code_input.text = code
  game._join_room()
  var join_limit := Time.get_ticks_msec() + 45000
  while game.player_index < 0 and Time.get_ticks_msec() < join_limit: await process_frame
  check(game._voice_room_ready(), "Android room join failed")
  print("ANDROID_ROOM_JOINED=", game._voice_room_ready())
  check(not game.voice_button.disabled, "Voice button unavailable in room")
  game.voice_button.pressed.emit()
  var active_limit := Time.get_ticks_msec() + 60000
  while not game.android_voice_bridge.active and Time.get_ticks_msec() < active_limit: await process_frame
  check(game.android_voice_bridge.active, "Android WebRTC connection failed")
  print("ANDROID_ROOM_VOICE_ACTIVE=",game.android_voice_bridge.active)
  await create_timer(10).timeout
  check(game.connected and not game.reconnecting, "Voice disconnected gameplay")
  game._show_voice_diagnostics()
  print("ANDROID_ACTIVE_DIAGNOSTICS_COMPLETED")
  game.set_voice_opt_in(false)
  await create_timer(2).timeout
  check(not game.android_voice_bridge.active and game.connected, "Opt-out interrupted room")
  game.queue_free(); await process_frame
  if failures.is_empty(): print("ANDROID_ROOM_NATIVE_PASS"); quit(0)
  else: print("ANDROID_ROOM_NATIVE_FAIL: ",failures); quit(1)
  return
 if not granted:
  check(not native.startWebRtcVoice(9001, true, "{}"), "Denied microphone started audio")
  print("ANDROID_PERMISSION_DENIAL_PASS")
 else:
  var statuses: Array[String] = []
  var offers: Array[String] = []
  native.voice_status.connect(func(state: String, _ticket: int, detail: String): statuses.append(state); print("ANDROID_NATIVE_STATUS=",state," ",detail))
  native.voice_signal.connect(func(kind: String, _payload: String, _ticket: int): offers.append(kind); print("ANDROID_NATIVE_SIGNAL=",kind))
  if "--expect-start-failure" in OS.get_cmdline_user_args():
   check(native.startWebRtcVoice(9010, true, "{}"), "Permission gate unexpectedly refused injected startup failure")
   var error_limit := Time.get_ticks_msec() + 30000
   while not "error" in statuses and Time.get_ticks_msec() < error_limit: await process_frame
   check("error" in statuses, "Injected audio failure was not reported")
   native.stopVoice(); await create_timer(2).timeout
   check(is_instance_valid(game.create_button), "Partial initialization failure interrupted gameplay")
   game.queue_free(); await process_frame
   if failures.is_empty(): print("ANDROID_PARTIAL_STARTUP_FAILURE_PASS"); quit(0)
   else: print("ANDROID_PARTIAL_STARTUP_FAILURE_FAIL: ",failures); quit(1)
   return
  for cycle in range(2):
   check(native.startWebRtcVoice(9002 + cycle, true, "{}"), "Native startup refused")
   var limit := Time.get_ticks_msec() + 45000
   while not "voice_offer" in offers and not "error" in statuses and Time.get_ticks_msec() < limit: await process_frame
   check("voice_offer" in offers, "Native offer missing")
   check(not "error" in statuses, "Native startup error")
   await create_timer(2).timeout
   check(not "error" in statuses, "Native error after offer creation")
   native.stopVoice()
   await create_timer(2).timeout
   offers.clear(); statuses.clear()
  print("ANDROID_NATIVE_RESTART_COMPLETED")
 check(is_instance_valid(game.create_button), "Voice interrupted game UI")
 game.queue_free(); await process_frame
 if failures.is_empty(): print("ANDROID_VOICE_RUNTIME_PASS"); quit(0)
 else: print("ANDROID_VOICE_RUNTIME_FAIL: ",failures); quit(1)
