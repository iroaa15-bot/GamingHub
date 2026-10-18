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
