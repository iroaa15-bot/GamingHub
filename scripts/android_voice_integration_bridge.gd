extends "res://scripts/android_voice_bridge.gd"
## JNI boundary compatibility only. Original capture/routing/lifecycle are inherited.
## Android JNISingleton methods are callable but not exposed by Object.has_method().
var _attaching_native := false

func _try_attach_native() -> void:
 if _attaching_native:
  return
 _attaching_native = true
 super._try_attach_native()
 _attaching_native = false

func attach_native(plugin: Object) -> void:
 if OS.get_name() != "Android":
  super.attach_native(plugin)
  return
 var version: Variant = plugin.call("getVoiceApiVersion")
 if typeof(version) not in [TYPE_INT,TYPE_FLOAT] or int(version) != 2:
  voice_unavailable.emit("Android voice plugin needs an update")
  return
 native_voice_bridge = plugin
 if not native_voice_bridge.is_connected("microphone_permission", _on_permission):
  native_voice_bridge.connect("microphone_permission", _on_permission)
 if not native_voice_bridge.is_connected("voice_status", _on_native_status):
  native_voice_bridge.connect("voice_status", _on_native_status)

# Bounded metadata only: no PCM, speech, tokens or room identifiers are stored.
var _health_captured := 0
var _health_incoming := 0
var _health_accepted := 0
var _health_last_sequence := -1
var _health_last_capture := -1
var _health_last_incoming := -1
func _ready() -> void:
 super._ready()
 outgoing_pcm.connect(_health_capture)
func _health_capture(_frame: String) -> void:
 _health_captured+=1
 _health_last_capture=Time.get_ticks_msec()
func receive_pcm(pcm: String, sequence: int) -> void:
 if active and local_opt_in and peer_opt_in and native_voice_bridge!=null:
  _health_incoming+=1
  _health_last_sequence=sequence
  _health_last_incoming=Time.get_ticks_msec()
  # Same single native call as the original bridge; observe its existing result.
  if bool(native_voice_bridge.playVoiceFrame(pcm,sequence)): _health_accepted+=1
func voice_health_snapshot() -> Dictionary:
 return {"active":active,"starting":starting,"local_consent":local_opt_in,"peer_consent":peer_opt_in,"captured_frames":_health_captured,"incoming_frames":_health_incoming,"accepted_frames":_health_accepted,"last_sequence":_health_last_sequence,"capture_age_ms":-1 if _health_last_capture<0 else Time.get_ticks_msec()-_health_last_capture,"incoming_age_ms":-1 if _health_last_incoming<0 else Time.get_ticks_msec()-_health_last_incoming}
