extends SceneTree
# Android-only permission diagnostic. A successful permission grant is not
# evidence that the native voice engine restarted.
var started_msec := 0
var permission_prompt_started := false

func _initialize() -> void:
    started_msec = Time.get_ticks_msec()
    call_deferred("_begin")

func _begin() -> void:
    if OS.get_name() != "Android":
        print("ANDROID_VOICE_RUNTIME_FAIL non-Android runtime")
        quit(1)
        return
    if OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
        print("ANDROID_VOICE_RUNTIME_FAIL permission was already granted before prompt")
        quit(1)
        return
    print("ANDROID_AFTER_VOICE_BUTTON")
    permission_prompt_started = true
    OS.request_permission("android.permission.RECORD_AUDIO")
    _poll_permission()

func _poll_permission() -> void:
    if OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
        print("ANDROID_PERMISSION_CALLBACK=true")
        # The native restart hook must be wired before this test can pass.
        print("ANDROID_VOICE_RUNTIME_FAIL native restart callback not connected")
        quit(1)
        return
    if Time.get_ticks_msec() - started_msec > 15000:
        print("ANDROID_PERMISSION_CALLBACK=false")
        print("ANDROID_VOICE_RUNTIME_FAIL permission denied or dialog timed out")
        quit(1)
        return
    await create_timer(0.25).timeout
    _poll_permission()
