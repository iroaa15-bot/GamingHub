extends SceneTree
# Android permission diagnostic. Never reports native voice success without
# a native restart signal; this prevents false PASS results.
var started_msec := 0
var requested := false
var finished := false

func _initialize() -> void:
    started_msec = Time.get_ticks_msec()
    call_deferred("_begin")

func _begin() -> void:
    if OS.get_name() != "Android":
        push_error("ANDROID_VOICE_RUNTIME_FAIL non-Android runtime")
        quit(1)
        return
    print("ANDROID_AFTER_VOICE_BUTTON")
    requested = true
    var granted := OS.request_permission("android.permission.RECORD_AUDIO")
    if granted:
        print("ANDROID_PERMISSION_CALLBACK=true")
        _verify_native_restart()
    else:
        # Android may return false while the permission dialog is pending.
        _poll_permission()

func _poll_permission() -> void:
    if finished:
        return
    if OS.get_granted_permissions().has("android.permission.RECORD_AUDIO"):
        print("ANDROID_PERMISSION_CALLBACK=true")
        _verify_native_restart()
        return
    if Time.get_ticks_msec() - started_msec > 15000:
        print("ANDROID_PERMISSION_CALLBACK=false")
        print("ANDROID_VOICE_RUNTIME_FAIL permission denied or timed out")
        quit(1)
        return
    await create_timer(0.25).timeout
    _poll_permission()

func _verify_native_restart() -> void:
    # The Android voice plugin API must be verified before this can be
    # connected to its real restart callback. Do not fabricate success.
    print("ANDROID_VOICE_RUNTIME_FAIL native restart integration not wired")
    quit(1)
