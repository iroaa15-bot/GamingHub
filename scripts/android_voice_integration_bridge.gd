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
