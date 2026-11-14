extends Node
## Android v2 PCM bridge. Microphone I/O starts only after server-acknowledged mutual consent.
signal outgoing_pcm(base64_pcm: String)
signal voice_unavailable(reason: String)
signal permission_ready(granted: bool)
signal status_changed(state: String, details: String)

var native_voice_bridge: Object = null
var local_opt_in := false
var peer_opt_in := false
var active := false
var starting := false
var request_id := 0

func _ready() -> void:
 _try_attach_native()

# A late native registration must not permanently disable voice after scene ready.
func _try_attach_native() -> void:
 if native_voice_bridge != null or OS.get_name() != "Android":
  return
 if not Engine.has_singleton("GamingHubVoice"):
  return
 attach_native(Engine.get_singleton("GamingHubVoice"))

# Also used by executable Godot tests with a fake native boundary.
func attach_native(plugin: Object) -> void:
 if not plugin.has_method("getVoiceApiVersion") or int(plugin.getVoiceApiVersion()) != 2:
  voice_unavailable.emit("Android voice plugin needs an update")
  return
 native_voice_bridge = plugin
 if not native_voice_bridge.is_connected("microphone_permission", _on_permission):
  native_voice_bridge.connect("microphone_permission", _on_permission)
 if not native_voice_bridge.is_connected("voice_status", _on_native_status):
  native_voice_bridge.connect("voice_status", _on_native_status)

func is_available() -> bool:
 _try_attach_native()
 return native_voice_bridge != null

func request_permission() -> void:
 _try_attach_native()
 if native_voice_bridge == null:
  permission_ready.emit(false)
  voice_unavailable.emit("Android voice plugin is unavailable")
 elif native_voice_bridge.hasMicrophonePermission():
  permission_ready.emit(true)
 else:
  native_voice_bridge.requestMicrophonePermission()

func _on_permission(granted: bool) -> void:
 permission_ready.emit(granted)

func set_consent(local_enabled: bool, peer_enabled: bool) -> void:
 _try_attach_native()
 local_opt_in = local_enabled
 peer_opt_in = peer_enabled
 if not (local_opt_in and peer_opt_in):
  stop_voice()
  return
 if active or starting:
  return
 if native_voice_bridge == null or not native_voice_bridge.hasMicrophonePermission():
  voice_unavailable.emit("Microphone permission or Android plugin unavailable")
  return
 request_id += 1
 starting = true
 status_changed.emit("starting", "")
 if not native_voice_bridge.startVoice(request_id):
  starting = false
  voice_unavailable.emit("Unable to start Android audio")

func _on_native_status(state: String, ticket: int, details: String) -> void:
 if state == "suspended":
  if active or starting:
   stop_voice()
   voice_unavailable.emit("Audio interrupted; enable voice again")
  return
 if ticket != request_id or not (local_opt_in and peer_opt_in):
  return
 if state == "started":
  starting = false
  active = true
  status_changed.emit("active", details)
 elif state == "error":
  stop_voice()
  voice_unavailable.emit(details)

func _process(_delta: float) -> void:
 if not active or not (local_opt_in and peer_opt_in) or native_voice_bridge == null:
  return
 for pcm in native_voice_bridge.drainCapturedFrames():
  outgoing_pcm.emit(str(pcm))

func receive_pcm(pcm: String, sequence: int) -> void:
 if active and local_opt_in and peer_opt_in and native_voice_bridge != null:
  native_voice_bridge.playVoiceFrame(pcm, sequence)

func stop_voice() -> void:
 request_id += 1 # Ignore already queued native callbacks from an older session.
 var was_running := active or starting
 active = false
 starting = false
 if native_voice_bridge != null and was_running:
  native_voice_bridge.stopVoice()
 if was_running:
  status_changed.emit("off", "")

func _exit_tree() -> void:
 local_opt_in = false
 peer_opt_in = false
 stop_voice()
