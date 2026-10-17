extends SceneTree

const Microphone = preload("res://scripts/voice_microphone_capture.gd")

func _initialize() -> void:
 var microphone = Microphone.new()
 assert(not microphone.is_capturing())
 assert(not microphone.start(null, true, true))
 assert(not microphone.start(get_root(), false, true))
 assert(not microphone.start(get_root(), true, false))
 assert(not microphone.is_capturing())
 assert(microphone.take_frames().is_empty())
 microphone.stop()
 assert(not microphone.is_capturing())
 print("VOICE_MICROPHONE_SMOKE_PASS")
 quit(0)
