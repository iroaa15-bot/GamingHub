extends Node
## Native Android PCM bridge. Never start the microphone without both players opting in.
## This node is deliberately transport-agnostic: caller sends the emitted base64
## payload as {type:"voice_audio",pcm:payload} over an authenticated room socket.
signal outgoing_pcm(base64_pcm: String)
signal voice_unavailable(reason: String)

var native_voice_bridge: Object = null
var local_opt_in := false
var peer_opt_in := false
var active := false

func _ready() -> void:
 if OS.get_name() != "Android":
  return
 if not Engine.has_singleton("GamingHubVoice"):
  voice_unavailable.emit("Android voice plugin is not installed")
  return
 native_voice_bridge = Engine.get_singleton("GamingHubVoice")
 if native_voice_bridge.has_signal("voice_frame"):
  native_voice_bridge.connect("voice_frame", _on_voice_frame)

func set_consent(local_enabled: bool, peer_enabled: bool) -> void:
 local_opt_in = local_enabled
 peer_opt_in = peer_enabled
 if not (local_opt_in and peer_opt_in):
  stop_voice()
  return
 if native_voice_bridge == null:
  voice_unavailable.emit("Native Android voice engine unavailable")
  return
 if not native_voice_bridge.hasMicrophonePermission():
  voice_unavailable.emit("Microphone permission required")
  return
 active = native_voice_bridge.startVoice()
 if not active:
  voice_unavailable.emit("Unable to start Android audio")

func _on_voice_frame(pcm: String) -> void:
 if active and local_opt_in and peer_opt_in:
  outgoing_pcm.emit(pcm)

func receive_pcm(pcm: String) -> void:
 if active and local_opt_in and peer_opt_in and native_voice_bridge != null:
  native_voice_bridge.playVoiceFrame(pcm)

func stop_voice() -> void:
 active = false
 if native_voice_bridge != null:
  native_voice_bridge.stopVoice()

func _exit_tree() -> void:
 stop_voice()
