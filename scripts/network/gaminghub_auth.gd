extends Node
## Optional Gaming Hub account client. Configure an HTTPS API URL before enabling.
## Does not change existing guest/offline gameplay or scene navigation.
signal auth_changed(authenticated: bool)
signal native_provider_result(provider: String, token: String, error: String)
var api_base: String = ""
## Access tokens stay in memory. Android Keystore protects the refresh credential.
static var session_token: String = ""
static var session_origin: String = ""
var access_token: String = ""
var refresh_token: String = ""
var secure_store: Object
var restoring := false
var refresh_after := 0
var active_provider := ""
var requested_provider := ""

func _ready() -> void:
    if Engine.has_singleton("GamingHubIdentity"):
        secure_store = Engine.get_singleton("GamingHubIdentity")
        if secure_store.has_signal("social_result"):
            secure_store.connect("social_result", _on_native_provider_result)
        # Explicit local debug-only acceptance request, with no real credentials.
        if OS.is_debug_build() and FileAccess.file_exists("user://identity_storage_probe.txt"):
            var mode := FileAccess.get_file_as_string("user://identity_storage_probe.txt").strip_edges()
            if mode in ["write", "read"]:
                print("GH_IDENTITY_STORAGE_PROBE_", mode.to_upper(), "_", "PASS" if secure_store.storageProbe(mode) else "FAIL")
    access_token = session_token
    var endpoint: String = str(ProjectSettings.get_setting("gaminghub/identity_api_url", ""))
    if FileAccess.file_exists("user://gaminghub_identity_endpoint.json"):
        var stored = JSON.parse_string(FileAccess.get_file_as_string("user://gaminghub_identity_endpoint.json"))
        if stored is Dictionary: endpoint = str(stored.get("url", endpoint))
    configure(endpoint)
    _restore_session.call_deferred()

func _restore_session() -> void:
    if secure_store == null or api_base.is_empty(): return
    var stored_session := str(secure_store.loadSession())
    if stored_session.is_empty(): return
    var saved: Variant = JSON.parse_string(stored_session)
    if not saved is Dictionary or str(saved.get("origin", "")) != session_origin: return
    refresh_token = str(saved.get("refresh_token", ""))
    if not refresh_token.is_empty(): await refresh_session()

func _accept_session(data: Dictionary) -> void:
    refresh_token = str(data.get("refresh_token", ""))
    refresh_after = Time.get_ticks_msec() + 840000
    # Persist before accepting the new token. No password or provider token is stored.
    if secure_store != null and not refresh_token.is_empty():
        secure_store.storeSession(JSON.stringify({"origin": session_origin, "refresh_token": refresh_token}))
    _remember_token(str(data.get("access_token", "")))

func refresh_session() -> Dictionary:
    if restoring or refresh_token.is_empty(): return {"ok": false, "status": 0}
    restoring = true
    var response := await _call("/auth/refresh", HTTPClient.METHOD_POST, {"refresh_token": refresh_token})
    restoring = false
    if response.get("ok", false): _accept_session(response.get("data", {}))
    elif int(response.get("status", 0)) == 401: _forget_session()
    return response

func _forget_session() -> void:
    refresh_token = ""
    if secure_store != null: secure_store.clearSession()
    _remember_token("")

func _on_native_provider_result(provider: String, token: String, error: String) -> void:
    if provider == active_provider: native_provider_result.emit(provider, token, error)

func sign_in_provider(provider: String) -> Dictionary:
    if provider not in ["google", "facebook"] or not active_provider.is_empty():
        return {"ok": false, "status": 0, "error": "Sign-in already in progress"}
    # Android JNISingleton dispatches Java calls dynamically; has_method() does
    # not expose its Java method map. The registered signal identifies this API.
    if secure_store == null or not secure_store.has_signal("social_result"):
        return {"ok": false, "status": 0, "error": "Native Android sign-in unavailable"}
    var availability := await _call("/auth/providers", HTTPClient.METHOD_GET)
    if not availability.get("ok", false) or not availability.get("data", {}).get(provider, false):
        return {"ok": false, "status": 503, "error": "Provider setup incomplete"}
    var facebook: Dictionary = {}
    if provider == "facebook":
        var config: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/identity_provider_config.json"))
        if config is Dictionary: facebook = config
        if str(facebook.get("facebook_app_id", "")).is_empty() or str(facebook.get("facebook_client_token", "")).is_empty() or str(facebook.get("facebook_app_id")) != str(availability.get("data", {}).get("facebook_app_id")):
            return {"ok": false, "status": 503, "error": "Facebook Android setup incomplete"}
    var challenge := await _call("/auth/challenge", HTTPClient.METHOD_POST, {"provider": provider})
    if not challenge.get("ok", false): return challenge
    var nonce: String = str(challenge.get("data", {}).get("nonce", ""))
    active_provider = provider
    if provider == "google": secure_store.call_deferred("requestGoogleLogin", str(challenge.get("data", {}).get("google_web_client_id", "")), nonce)
    else: secure_store.call_deferred("requestFacebookLogin", str(facebook.get("facebook_app_id")), str(facebook.get("facebook_client_token")))
    var result: Array = await native_provider_result
    active_provider = ""
    if not str(result[2]).is_empty(): return {"ok": false, "status": 0, "error": "Sign-in cancelled or provider unavailable"}
    var response := await _call("/auth/social", HTTPClient.METHOD_POST, {"provider": provider, "nonce": nonce, "token": str(result[1])})
    result.clear()
    if response.get("ok", false): _accept_session(response.get("data", {}))
    return response

func _remember_token(token: String) -> void:
    access_token = token
    session_token = token
    auth_changed.emit(not token.is_empty())

func configure(https_api_url: String) -> bool:
    var normalized := https_api_url.strip_edges().trim_suffix("/")
    if not normalized.begins_with("https://") or "@" in normalized or "?" in normalized or "#" in normalized:
        return false
    if not session_origin.is_empty() and session_origin != normalized:
        _forget_session()
    session_origin = normalized
    api_base = normalized + "/api"
    return true

func _call(endpoint: String, method: int, data: Dictionary = {}) -> Dictionary:
    if api_base.is_empty():
        return {"ok": false, "status": 0, "error": "Backend URL not configured"}
    if endpoint != "/auth/refresh" and not refresh_token.is_empty() and Time.get_ticks_msec() >= refresh_after:
        var renewed := await refresh_session()
        if not renewed.get("ok", false): return renewed
    var request_node := HTTPRequest.new()
    request_node.timeout = 15.0
    add_child(request_node)
    var headers := PackedStringArray(["Content-Type: application/json"])
    if not access_token.is_empty():
        headers.append("Authorization: Bearer " + access_token)
    var body: String = JSON.stringify(data) if method != HTTPClient.METHOD_GET else ""
    var start_error := request_node.request(api_base + endpoint, headers, method, body)
    if start_error != OK:
        request_node.queue_free()
        return {"ok": false, "status": 0, "error": "Network request failed to start"}
    var result: Array = await request_node.request_completed
    request_node.queue_free()
    var status_code: int = result[1]
    if result[0] != HTTPRequest.RESULT_SUCCESS:
        return {"ok": false, "status": 0, "error": "Account server unavailable; guest play is available"}
    if status_code == 401 and endpoint not in ["/auth/login", "/auth/register"]:
        _forget_session()
    var parsed = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
    if not parsed is Dictionary:
        parsed = {}
    return {"ok": status_code >= 200 and status_code < 300, "status": status_code, "data": parsed}

func register_account(email: String, password: String, display_name: String) -> Dictionary:
    var response := await _call("/auth/register", HTTPClient.METHOD_POST, {"email": email, "password": password, "display_name": display_name})
    if response.get("ok", false):
        _accept_session(response.get("data", {}))
    return response

func login(email: String, password: String) -> Dictionary:
    var response := await _call("/auth/login", HTTPClient.METHOD_POST, {"email": email, "password": password})
    if response.get("ok", false):
        _accept_session(response.get("data", {}))
    return response

func guest() -> Dictionary:
    var response := await _call("/auth/guest", HTTPClient.METHOD_POST)
    if response.get("ok", false):
        _accept_session(response.get("data", {}))
    return response

func upgrade_guest(email: String, password: String, display_name: String) -> Dictionary:
    var response := await _call("/auth/upgrade", HTTPClient.METHOD_POST, {"email": email, "password": password, "display_name": display_name})
    if response.get("ok", false):
        _accept_session(response.get("data", {}))
    return response

func profile() -> Dictionary:
    return await _call("/me", HTTPClient.METHOD_GET)

func logout() -> Dictionary:
    var response := await _call("/auth/logout", HTTPClient.METHOD_POST)
    # Local logout always removes the credential, including when the server is offline.
    _forget_session()
    if secure_store != null and secure_store.has_signal("social_result"): secure_store.providerSignOut()
    return response
