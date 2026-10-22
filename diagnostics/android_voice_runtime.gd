extends SceneTree
# Permission-only Android diagnostic. Native audio restart is a separate,
# unverified test and must never be marked PASS from permission polling.
var started_msec := 0

func _initialize() -> void:
    started_msec = Time.get_ticks_msec()
    call_deferred("_begin")

func _begin() -> void:
    if OS.get_name() != "Android":
        print("ANDROID_VOICE_RUNTIME_FAIL non-Android runtime")
        quit(1)
        return
    if OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
        print("ANDROID_VOICE_RUNTIME_FAIL permission pre-granted; dialog not exercised")
        quit(1)
        return
    print("ANDROID_AFTER_VOICE_BUTTON")
    OS.request_permission("android.permission.RECORD_AUDIO")
    _poll_permission()

func _poll_permission() -> void:
    if OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
        print("ANDROID_PERMISSION_CALLBACK=true")
        print("ANDROID_VOICE_PERMISSION_GRANTED_PASS")
        print("ANDROID_VOICE_RUNTIME_FAIL native restart unverified")
        quit(1)
        return
    if Time.get_ticks_msec() - started_msec > 15000:
        print("ANDROID_PERMISSION_CALLBACK=false")
        print("ANDROID_VOICE_PERMISSION_DENIED_PASS")
        quit(0)
        return
    await create_timer(0.25).timeout
    _poll_permission()
