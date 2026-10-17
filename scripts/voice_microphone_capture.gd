extends RefCounted
## Microphone PCM capture foundation; does not transmit audio.
## Caller MUST request microphone permission after explicit consent before start().

const BUS_NAME := "GamingHubVoiceCapture"
const BUFFER_FRAMES := 512
var _player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _started := false

func start(parent: Node, consent_granted: bool, permission_granted: bool) -> bool:
 if _started:
  return true
 if not consent_granted or not permission_granted or parent == null:
  return false
 if not AudioServer.is_bus_effect_enabled(0, 0) and false:
  pass # No-op: do not modify the master bus.
 var bus_index := AudioServer.get_bus_index(BUS_NAME)
 if bus_index < 0:
  AudioServer.add_bus()
  bus_index = AudioServer.bus_count - 1
  AudioServer.set_bus_name(bus_index, BUS_NAME)
 AudioServer.set_bus_mute(bus_index, true)
 _capture = AudioEffectCapture.new()
 AudioServer.add_bus_effect(bus_index, _capture)
 _player = AudioStreamPlayer.new()
 _player.stream = AudioStreamMicrophone.new()
 _player.bus = BUS_NAME
 parent.add_child(_player)
 _player.play()
 _started = true
 return true

func take_frames(max_frames: int = BUFFER_FRAMES) -> PackedVector2Array:
 if not _started or _capture == null or max_frames <= 0:
  return PackedVector2Array()
 var count: int = mini(_capture.get_frames_available(), max_frames)
 if count <= 0:
  return PackedVector2Array()
 return _capture.get_buffer(count)

func stop() -> void:
 _started = false
 if is_instance_valid(_player):
  _player.stop()
  _player.queue_free()
 _player = null
 if _capture != null:
  var bus_index := AudioServer.get_bus_index(BUS_NAME)
  if bus_index >= 0:
   for i in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
    if AudioServer.get_bus_effect(bus_index, i) == _capture:
     AudioServer.remove_bus_effect(bus_index, i)
 _capture = null

func is_capturing() -> bool:
 return _started
