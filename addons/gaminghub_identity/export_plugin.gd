@tool
extends EditorExportPlugin
func _get_name() -> String:
 return "GamingHubIdentity"
func _supports_platform(platform: EditorExportPlatform) -> bool:
 return platform is EditorExportPlatformAndroid
func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
 return PackedStringArray(["res://addons/gaminghub_identity/bin/gaminghub-identity-%s.aar" % ("debug" if debug else "release")])
func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
 return PackedStringArray(["androidx.credentials:credentials:1.5.0", "androidx.credentials:credentials-play-services-auth:1.5.0", "com.google.android.libraries.identity.googleid:googleid:1.1.1", "com.facebook.android:facebook-login:19.0.0"])
func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
 var config: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/identity_provider_config.json"))
 if not config is Dictionary: return ""
 var app_id: String = str(config.get("facebook_app_id", ""))
 if app_id.is_empty() or not app_id.is_valid_int() or app_id.begins_with("-"): return ""
 return '<meta-data android:name="com.facebook.sdk.ApplicationId" android:value="fb%s" /><activity android:name="com.facebook.CustomTabActivity" android:exported="true"><intent-filter><action android:name="android.intent.action.VIEW"/><category android:name="android.intent.category.DEFAULT"/><category android:name="android.intent.category.BROWSABLE"/><data android:scheme="fb%s"/></intent-filter></activity>' % [app_id, app_id]
func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
 # Account login and app-private encrypted storage need none of these permissions.
 var contents := ""
 for permission in ["android.permission.AD_ID", "com.google.android.gms.permission.AD_ID", "android.permission.READ_BASIC_PHONE_STATE", "android.permission.READ_PHONE_STATE", "android.permission.READ_EXTERNAL_STORAGE", "android.permission.WRITE_EXTERNAL_STORAGE", "android.permission.READ_CONTACTS", "android.permission.WRITE_CONTACTS", "android.permission.USE_BIOMETRIC", "android.permission.USE_FINGERPRINT", "android.permission.ACCESS_ADSERVICES_ATTRIBUTION", "android.permission.ACCESS_ADSERVICES_AD_ID", "android.permission.ACCESS_ADSERVICES_CUSTOM_AUDIENCE", "android.permission.ACCESS_ADSERVICES_TOPICS", "com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE", "android.permission.FOREGROUND_SERVICE", "android.permission.WAKE_LOCK"]:
  contents += '<uses-permission xmlns:tools="http://schemas.android.com/tools" android:name="%s" tools:node="remove" />' % permission
 return contents
