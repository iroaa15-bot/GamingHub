@tool
extends EditorExportPlugin
func _get_name() -> String:
 return "GamingHubVoice"
func _supports_platform(platform: EditorExportPlatform) -> bool:
 return platform is EditorExportPlatformAndroid
func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
 var variant := "debug" if debug else "release"
 # A missing library fails export instead of silently shipping without a microphone engine.
 return PackedStringArray(["res://addons/gaminghub_voice/bin/gaminghub-voice-%s.aar" % variant])
func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
 return PackedStringArray(["org.jetbrains.kotlin:kotlin-stdlib:2.1.20", "io.github.webrtc-sdk:android:144.7559.15"])
