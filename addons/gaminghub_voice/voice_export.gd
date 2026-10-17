@tool
extends EditorExportPlugin

# This editor plugin is intentionally NOT enabled in project.godot.
# A reviewed voice-plugin-debug.aar must be copied to this folder before
# activating it for a separate custom-Gradle Android debug export.
const AAR_PATH := "res://addons/gaminghub_voice/voice-plugin-debug.aar"

func _supports_platform(platform: EditorExportPlatform) -> bool:
    return platform.get_os_name() == "Android"

func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
    if not _supports_platform(platform):
        return PackedStringArray()
    var aar := ProjectSettings.globalize_path(AAR_PATH)
    if not FileAccess.file_exists(aar):
        push_error("GamingHubVoice: missing reviewed AAR; refusing Android export integration")
        return PackedStringArray()
    return PackedStringArray([aar])

func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
    if not _supports_platform(platform):
        return PackedStringArray()
    if not FileAccess.file_exists(ProjectSettings.globalize_path(AAR_PATH)):
        return PackedStringArray()
    return PackedStringArray([
        "io.github.webrtc-sdk:android:150.7871.01",
        "androidx.core:core-ktx:1.13.1"
    ])
