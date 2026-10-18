extends RefCounted
## Safe adapter for optional Android native speakerphone plugin.
## This file does not enable recording or replace existing PCM transport.
var _plugin: Object

func available() -> bool:
 if OS.get_name() != "Android":
  return false
 if not Engine.has_singleton("GamingHubVoice"):
  return false
 _plugin = Engine.get_singleton("GamingHubVoice")
 return _plugin != null

func start_after_consent() -> bool:
 if not available():
  return false
 return bool(_plugin.call("startVoice"))

func stop() -> void:
 if _plugin != null and is_instance_valid(_plugin):
  _plugin.call("stopVoice")

func diagnostics() -> Dictionary:
 if not available():
  return {"available": false, "running": false, "aec": false, "ns": false, "agc": false}
 return {
  "available": true,
  "running": bool(_plugin.call("isRunning")),
  "aec": bool(_plugin.call("isAecEnabled")),
  "ns": bool(_plugin.call("isNsEnabled")),
  "agc": bool(_plugin.call("isAgcEnabled"))
 }

## Empty packet means the native recorder has not produced a full 20ms frame.
func poll_pcm() -> String:
 if _plugin == null or not is_instance_valid(_plugin):
  return ""
 if not bool(_plugin.call("isRunning")):
  return ""
 return str(_plugin.call("pollPcm"))

func push_pcm(encoded: String) -> bool:
 if _plugin == null or not is_instance_valid(_plugin):
  return false
 if encoded.length() != 856 or not bool(_plugin.call("isRunning")):
  return false
 return bool(_plugin.call("pushPcm", encoded))

## WebRTC signaling interface. Call only after mutual room consent.
func start_webrtc() -> bool:
 if not available() or not _plugin.has_method("startWebRtc"):
  return false
 return bool(_plugin.call("startWebRtc"))

func stop_webrtc() -> void:
 if _plugin != null and is_instance_valid(_plugin) and _plugin.has_method("stopWebRtc"):
  _plugin.call("stopWebRtc")

func set_webrtc_muted(muted: bool) -> bool:
 if _plugin != null and is_instance_valid(_plugin) and _plugin.has_method("setWebRtcMuted"):
  return bool(_plugin.call("setWebRtcMuted", muted))
 return false

func offer_webrtc() -> void:
 if _plugin != null and is_instance_valid(_plugin):
  _plugin.call("webRtcOffer")

func remote_webrtc_description(kind: String, sdp: String) -> void:
 if _plugin != null and is_instance_valid(_plugin):
  _plugin.call("webRtcRemoteDescription", kind, sdp)

func remote_webrtc_candidate(candidate: String, mid: String, line: int) -> void:
 if _plugin != null and is_instance_valid(_plugin):
  _plugin.call("webRtcRemoteCandidate", candidate, mid, line)

func poll_webrtc_event() -> String:
 if _plugin == null or not is_instance_valid(_plugin):
  return ""
 return str(_plugin.call("pollWebRtcEvent"))
