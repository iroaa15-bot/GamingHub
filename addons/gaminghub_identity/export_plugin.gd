@tool
extends EditorExportPlugin
func _get_name() -> String:
 return "GamingHubIdentity"
func _supports_platform(platform: EditorExportPlatform) -> bool:
 return platform is EditorExportPlatformAndroid
func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
 return PackedStringArray(["res://addons/gaminghub_identity/bin/gaminghub-identity-%s.aar" % ("debug" if debug else "release")])
