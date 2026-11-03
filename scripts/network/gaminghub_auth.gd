extends Node
## Optional Gaming Hub account client. Configure an HTTPS API URL before enabling.
## Does not change existing guest/offline gameplay or scene navigation.
signal auth_changed(authenticated: bool)
var api_base: String = ""
## Process-memory session only: never write bearer tokens or passwords to user:// files.
static var session_token: String = ""
var access_token: String = ""

func _ready() -> void:
    access_token = session_token

func _remember_token(token: String) -> void:
    access_token = token
    session_token = token
    auth_changed.emit(not token.is_empty())

func configure(https_api_url: String) -> bool:
    var normalized := https_api_url.strip_edges().trim_suffix("/")
    if not normalized.begins_with("https://"):
        return false
    api_base = normalized + "/api"
    return true

func _call(endpoint: String, method: int, data: Dictionary = {}) -> Dictionary:
    if api_base.is_empty():
        return {"ok": false, "status": 0, "error": "Backend URL not configured"}
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
    var parsed = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
    if not parsed is Dictionary:
        parsed = {}
    return {"ok": status_code >= 200 and status_code < 300, "status": status_code, "data": parsed}

func register_account(email: String, password: String, display_name: String) -> Dictionary:
    var response := await _call("/auth/register", HTTPClient.METHOD_POST, {"email": email, "password": password, "display_name": display_name})
    if response.get("ok", false):
        _remember_token(str(response.get("data", {}).get("access_token", "")))
    return response

func login(email: String, password: String) -> Dictionary:
    var response := await _call("/auth/login", HTTPClient.METHOD_POST, {"email": email, "password": password})
    if response.get("ok", false):
        _remember_token(str(response.get("data", {}).get("access_token", "")))
    return response

func guest() -> Dictionary:
    var response := await _call("/auth/guest", HTTPClient.METHOD_POST)
    if response.get("ok", false):
        _remember_token(str(response.get("data", {}).get("access_token", "")))
    return response

func upgrade_guest(email: String, password: String, display_name: String) -> Dictionary:
    var response := await _call("/auth/upgrade", HTTPClient.METHOD_POST, {"email": email, "password": password, "display_name": display_name})
    if response.get("ok", false):
        _remember_token(str(response.get("data", {}).get("access_token", access_token)))
    return response

func profile() -> Dictionary:
    return await _call("/me", HTTPClient.METHOD_GET)

func logout() -> Dictionary:
    var response := await _call("/auth/logout", HTTPClient.METHOD_POST)
    if response.get("ok", false):
        _remember_token("")
    return response
