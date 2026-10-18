extends SceneTree
const AndroidVoiceBridge = preload("res://scripts/android_voice_bridge.gd")

func _initialize() -> void:
 var bridge = AndroidVoiceBridge.new()
 # On headless CI / Windows the native plugin must not be required.
 if OS.get_name() != "Android":
  if bridge.available():
   push_error("Android voice plugin must not appear on non-Android platforms")
   quit(1)
   return
  if bridge.start_after_consent():
   push_error("Native microphone started without Android plugin")
   quit(1)
   return
  if not bridge.poll_pcm().is_empty():
   push_error("Native bridge produced PCM without a running engine")
   quit(1)
   return
  if bridge.push_pcm(""):
   push_error("Native bridge accepted invalid audio")
   quit(1)
   return
  bridge.stop()
  var info: Dictionary = bridge.diagnostics()
  if bool(info.get("available", true)) or bool(info.get("running", true)):
   push_error("Native bridge fallback diagnostics incorrect")
   quit(1)
   return
 print("ANDROID_VOICE_BRIDGE_SMOKE_PASS")
 quit(0)
