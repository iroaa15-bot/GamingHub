@tool
extends EditorExportPlugin
func _get_name() -> String:
 return "GamingHubIdentity"
func _supports_platform(platform: EditorExportPlatform) -> bool:
 return platform is EditorExportPlatformAndroid
func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
 return PackedStringArray(["res://addons/gaminghub_identity/bin/gaminghub-identity-%s.aar" % ("debug" if debug else "release")])
func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
 # Account login and app-private encrypted storage need none of these permissions.
 var contents := ""
 for permission in ["android.permission.AD_ID", "com.google.android.gms.permission.AD_ID", "android.permission.READ_BASIC_PHONE_STATE", "android.permission.READ_PHONE_STATE", "android.permission.READ_EXTERNAL_STORAGE", "android.permission.WRITE_EXTERNAL_STORAGE", "android.permission.READ_CONTACTS", "android.permission.WRITE_CONTACTS"]:
  contents += '<uses-permission xmlns:tools="http://schemas.android.com/tools" android:name="%s" tools:node="remove" />' % permission
 return contents
