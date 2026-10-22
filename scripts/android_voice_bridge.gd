extends Node
## Android v2 PCM bridge. Microphone I/O starts only after server-acknowledged mutual consent.
signal outgoing_pcm(base64_pcm: String)
signal outgoing_signal(kind: String, payload: Dictionary)
signal voice_unavailable(reason: String)
signal permission_ready(granted: bool)
signal status_changed(state: String, details: String)

var native_voice_bridge: Object = null
var local_opt_in := false
var peer_opt_in := false
var active := false
var starting := false
var request_id := 0
var caller := false
var ice_config: Dictionary = {}
var native_attach_in_progress := false
var native_webrtc_supported := false

func _ready() -> void:
 _try_attach_native()

# A late native registration must not permanently disable voice after scene ready.
func _try_attach_native() -> void:
 if native_voice_bridge != null or native_attach_in_progress or OS.get_name() != "Android":
  return
 var found := Engine.has_singleton("GamingHubVoice")
 print("[GH_VOICE_DIAG] discovery singleton_found=", found)
 if not found:
  return
 native_attach_in_progress = true
 attach_native(Engine.get_singleton("GamingHubVoice"))
 native_attach_in_progress = false

# Also used by executable Godot tests with a fake native boundary.
func attach_native(plugin: Object) -> void:
 # Godot 4.5.1 JNISingleton dispatches calls via callp(), but does not expose
 # registered Java methods through Object.has_method(). Negotiate directly.
 var jni_plugin := plugin != null and plugin.get_class() == "JNISingleton"
 print("[GH_VOICE_DIAG] attach plugin_null=", plugin == null, " plugin_class=", plugin.get_class() if plugin != null else "null", " jni=", jni_plugin)
 if plugin == null or (not jni_plugin and not plugin.has_method("getVoiceApiVersion")):
  print("[GH_VOICE_DIAG] rejected reason=version_method_unavailable")
  voice_unavailable.emit("Android voice plugin needs an update")
  return
 var api_version := int(plugin.getVoiceApiVersion())
 print("[GH_VOICE_DIAG] api_version=", api_version, " expected=2")
 if api_version != 2:
  print("[GH_VOICE_DIAG] rejected reason=version_mismatch")
  voice_unavailable.emit("Android voice plugin needs an update")
  return
 native_webrtc_supported = (jni_plugin or plugin.has_method("supportsWebRtcVoice")) and bool(plugin.supportsWebRtcVoice())
 print("[GH_VOICE_DIAG] attach_success webrtc_supported=", native_webrtc_supported)
 native_voice_bridge = plugin
 if plugin.has_signal("voice_signal") and not plugin.is_connected("voice_signal", _on_native_signal):
  plugin.connect("voice_signal", _on_native_signal)
 if not native_voice_bridge.is_connected("microphone_permission", _on_permission):
  native_voice_bridge.connect("microphone_permission", _on_permission)
 if not native_voice_bridge.is_connected("voice_status", _on_native_status):
  native_voice_bridge.connect("voice_status", _on_native_status)

func uses_webrtc() -> bool:
 return native_voice_bridge != null and native_webrtc_supported

func configure_webrtc(initiator: bool, config: Dictionary) -> void:
 caller = initiator
 ice_config = config.duplicate(true)

func _on_native_signal(kind: String, payload_json: String, ticket: int) -> void:
 if ticket != request_id or not (local_opt_in and peer_opt_in):
  return
 var payload: Variant = JSON.parse_string(payload_json)
 if payload is Dictionary and kind in ["voice_offer", "voice_answer", "voice_ice"]:
  outgoing_signal.emit(kind, payload)

func receive_signal(kind: String, payload: Dictionary) -> void:
 if uses_webrtc() and (local_opt_in and peer_opt_in) and (active or starting):
  native_voice_bridge.receiveWebRtcSignal(kind, JSON.stringify(payload), request_id)

func is_available() -> bool:
 # UI reads must never initialize JNI or reenter a failure callback.
 return native_voice_bridge != null

func request_permission() -> void:
 print("[GH_VOICE_DIAG] request_permission entry attached=", native_voice_bridge != null)
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
 print("[GH_VOICE_DIAG] set_consent local=", local_enabled, " peer=", peer_enabled, " attached=", native_voice_bridge != null)
 local_opt_in = local_enabled
 peer_opt_in = peer_enabled
 if not (local_opt_in and peer_opt_in):
  stop_voice()
  return
 _try_attach_native()
 if active or starting:
  return
 if native_voice_bridge == null or not native_voice_bridge.hasMicrophonePermission():
  voice_unavailable.emit("Microphone permission or Android plugin unavailable")
  return
 request_id += 1
 starting = true
 status_changed.emit("starting", "")
 var accepted: bool = bool(native_voice_bridge.startWebRtcVoice(request_id, caller, JSON.stringify(ice_config))) if uses_webrtc() else bool(native_voice_bridge.startVoice(request_id))
 if not accepted:
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
 elif state == "reconnecting":
  active = false
  starting = true
  status_changed.emit("reconnecting", "")
 elif state == "error":
  stop_voice()
  voice_unavailable.emit(details)

func _process(_delta: float) -> void:
 if uses_webrtc() or not active or not (local_opt_in and peer_opt_in) or native_voice_bridge == null:
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
