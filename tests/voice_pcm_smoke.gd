extends SceneTree
const PCM = preload("res://scripts/voice_pcm_transport.gd")

func _initialize() -> void:
 var codec = PCM.new()
 var frames := PackedVector2Array()
 frames.resize(960)
 for i in range(frames.size()):
  frames[i] = Vector2(0.25, 0.25)
 var packets: Array[String] = codec.encode_frames(frames)
 if packets.size() != 1 or packets[0].length() != 856:
  push_error("PCM 48kHz to 16kHz packetization failed")
  quit(1)
  return
 var decoded := Marshalls.base64_to_raw(packets[0])
 if decoded.size() != 640:
  push_error("PCM packet size invalid")
  quit(1)
  return
 if decoded[0] == 0 and decoded[1] == 0:
  push_error("PCM nonzero input unexpectedly encoded as silence")
  quit(1)
  return
 codec.stop()
 if codec.receive_packet(packets[0]):
  push_error("PCM accepted audio without active playback")
  quit(1)
  return
 print("VOICE_PCM_SMOKE_PASS")
 quit(0)
