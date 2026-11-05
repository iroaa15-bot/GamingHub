extends Node
## Explicit opt-in local transport. Never reads or changes production network configuration.
signal state_changed(snapshot: Dictionary)
signal event_received(message: Dictionary)
signal protocol_ready(capabilities: Dictionary)
signal connection_changed(ready: bool)
const PROTOCOL := 3
var socket := WebSocketPeer.new()
var endpoint := ""
var capabilities: Dictionary = {}
var state: Dictionary = {}
var code := ""
var token := ""
var player := -1
var requested_game := ""
var last_error := ""
var error_count := 0
var _previous := WebSocketPeer.STATE_CLOSED
var _resume_requested := false
var _started_at := 0
var terms_accepted := false
var authenticate_local := false
var _auth_token := ""
var _auth_expiry := 0
var _request: HTTPRequest
var _renewing := false
var _renew_retry_at := 0
var _auto_resume := true
var _resume_until := 0
var _resume_retry_at := 0
var _binding_account := false

func _ready() -> void:
 var account=get_tree().root.get_node_or_null("GamingHubAccount")
 if account!=null:account.auth_changed.connect(_account_changed)

func _account_changed(_authenticated: bool) -> void:
 if bool(capabilities.get("identity_accounts",false)):_bind_current_account.call_deferred()

func _bind_current_account() -> void:
 if _binding_account:return
 var account=get_tree().root.get_node_or_null("GamingHubAccount")
 var origin: String=endpoint.replace("wss://","https://").trim_suffix("/")
 if account==null or origin!=str(account.session_origin):return
 _binding_account=true
 var transport=socket
 var deadline:=Time.get_ticks_msec()+16000
 while account.restoring and Time.get_ticks_msec()<deadline:
  await get_tree().process_frame
 if not account.restoring and not account.refresh_token.is_empty() and Time.get_ticks_msec()>=account.refresh_after:
  await account.refresh_session()
 if socket==transport and socket.get_ready_state()==WebSocketPeer.STATE_OPEN and bool(capabilities.get("identity_accounts",false)):
  send_action("duel_auth_bind",{"access_token":str(account.access_token)})
 _binding_account=false

static func service_configuration() -> Dictionary:
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/duel_service.json"))
 return data if data is Dictionary else {}


static func allowed_endpoint(value: String) -> bool:
 if value.begins_with("wss://"):
  var configuration := service_configuration()
  return bool(configuration.get("enabled",false)) and bool(configuration.get("availability_verified",false)) and value == str(configuration.get("endpoint","")) and value.trim_prefix("wss://").trim_suffix("/") == str(configuration.get("verified_host","")) and str(configuration.get("verified_host","")).ends_with(".onrender.com") and "gaminghub-multiplayer.onrender.com" not in value
 var regex := RegEx.new()
 regex.compile("^ws://(127\\.0\\.0\\.1|localhost|10\\.[0-9]+\\.[0-9]+\\.[0-9]+|192\\.168\\.[0-9]+\\.[0-9]+|172\\.(1[6-9]|2[0-9]|3[01])\\.[0-9]+\\.[0-9]+):[0-9]{1,5}/?$")
 if regex.search(value) == null: return false
 var host := value.trim_prefix("ws://").get_slice(":",0)
 var port := int(value.trim_prefix("ws://").get_slice(":",1).trim_suffix("/"))
 if port < 1 or port > 65535: return false
 if host != "localhost":
  for part in host.split("."):
   if int(part) > 255: return false
 return true

static func endpoint_from_args() -> String:
 # adb/run-as fixture, debug APK only; never a public endpoint or production setting.
 if OS.is_debug_build() and FileAccess.file_exists("user://gaminghub_debug_endpoint.txt"):
  var local_value: String=FileAccess.get_file_as_string("user://gaminghub_debug_endpoint.txt").strip_edges()
  if local_value.begins_with("ws://127.0.0.1:") and allowed_endpoint(local_value):return local_value
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--duel-local="):
   var value := arg.trim_prefix("--duel-local=")
   return value if allowed_endpoint(value) else ""
 var configuration := service_configuration()
 var configured := str(configuration.get("endpoint",""))
 return configured if allowed_endpoint(configured) else ""

func connect_endpoint(value: String) -> Error:
 if not allowed_endpoint(value):
  _error("Service is not configured or this endpoint is not approved")
  return ERR_INVALID_PARAMETER
 socket.close()
 if not endpoint.is_empty() and endpoint != value:
  _auth_token = ""
  _auth_expiry = 0
  token = ""
  code = ""
  state = {}
 endpoint = value
 _auto_resume = true
 capabilities = {}
 if value.begins_with("wss://") or authenticate_local:
  if not terms_accepted:
   _error("Accept the room terms before connecting")
   return ERR_UNAUTHORIZED
  if not _auth_token.is_empty() and Time.get_ticks_msec() < _auth_expiry:
   return _open_socket()
  if is_instance_valid(_request): _request.queue_free()
  _request = HTTPRequest.new()
  _request.timeout = 65
  _request.body_size_limit = 4096
  add_child(_request)
  _request.request_completed.connect(_authenticated)
  var session_url := value.replace("wss://","https://").replace("ws://","http://").trim_suffix("/")+"/session"
  return _request.request(session_url,PackedStringArray(["X-GamingHub-Terms: 1"]))
 return _open_socket()

func _authenticated(result: int, code_status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
 if result != HTTPRequest.RESULT_SUCCESS or code_status != 200:
  _error("Authentication service unavailable: " + str(code_status))
  event_received.emit({"type":"duel_error","message":last_error})
  return
 var value: Variant = JSON.parse_string(body.get_string_from_utf8())
 if not value is Dictionary or str(value.get("token","")).is_empty():
  _error("Invalid authentication response")
  return
 _auth_token = str(value.token)
 _auth_expiry = Time.get_ticks_msec()+maxi(0,int(value.get("expires_in",0))-30)*1000
 _open_socket()

func _open_socket() -> Error:
 socket = WebSocketPeer.new()
 socket.inbound_buffer_size = 262144
 if not _auth_token.is_empty(): socket.handshake_headers = PackedStringArray(["Authorization: Bearer "+_auth_token])
 _previous = WebSocketPeer.STATE_CLOSED
 _started_at = Time.get_ticks_msec()
 var result := socket.connect_to_url(endpoint)
 if result != OK: _error("Connection failed: " + str(result))
 return result

func _process(_delta: float) -> void:
 if not _renewing and not _auth_token.is_empty() and bool(capabilities.get("session_refresh",false)) and Time.get_ticks_msec()>=_renew_retry_at and Time.get_ticks_msec()>=_auth_expiry-60000:
  _renew_authentication()
 socket.poll()
 var current := socket.get_ready_state()
 if current == WebSocketPeer.STATE_OPEN:
  if _previous != WebSocketPeer.STATE_OPEN:
   var hello := {"type":"duel_hello","protocol":PROTOCOL}
   if not requested_game.is_empty():hello["game_id"]=requested_game
   socket.send_text(JSON.stringify(hello))
  while socket.get_available_packet_count() > 0:
   var value: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
   if value is Dictionary: _received(value)
 elif current == WebSocketPeer.STATE_CLOSED and _previous != WebSocketPeer.STATE_CLOSED:
  capabilities = {}
  connection_changed.emit(false)
  if _auto_resume and not code.is_empty() and not token.is_empty() and not bool(state.get("closed",false)):
   if _resume_until==0:_resume_until=Time.get_ticks_msec()+80000
   _resume_requested=true
   _resume_retry_at=Time.get_ticks_msec()+1000
 if current==WebSocketPeer.STATE_CLOSED and _auto_resume and _resume_requested and _resume_until>Time.get_ticks_msec() and Time.get_ticks_msec()>=_resume_retry_at:
  _resume_retry_at=Time.get_ticks_msec()+4000
  connect_endpoint(endpoint)
 if current == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() - _started_at > 10000:
  socket.close()
  _error("Local connection timed out")
 _previous = current

func _received(message: Dictionary) -> void:
 match str(message.get("type", "")):
  "duel_capabilities":
   if int(message.get("protocol", 0)) != PROTOCOL:
    _error("Incompatible server protocol")
    close_transport()
    return
   capabilities = message
   if bool(capabilities.get("identity_accounts",false)):
    _bind_current_account.call_deferred()
   connection_changed.emit(true)
   protocol_ready.emit(message)
   if _resume_requested:
    _resume_requested = false
    send_action("duel_resume", {"code":code,"token":token})
  "duel_created", "duel_joined", "duel_resumed":
   _resume_until=0
   _resume_retry_at=0
   code = str(message.get("code", ""))
   token = str(message.get("token", ""))
   player = int(message.get("player", -1))
   if message.get("type")!="duel_resumed":load("res://scripts/room_audio_policy.gd").acquire(get_tree()).effect("room_create" if message.get("type")=="duel_created" else "player_join")
   if bool(capabilities.get("voice",false)):load("res://scripts/room_audio_policy.gd").acquire(get_tree()).membership(self,true)
  "duel_state":
   if str(message.get("code", "")) == code:
    state = message
    if bool(state.get("closed",false)):
     token = ""
     code = ""
     load("res://scripts/room_audio_policy.gd").acquire(get_tree()).membership(self,false)
    state_changed.emit(state)
  "duel_error":
   _error(str(message.get("message", "Protocol error")))
 event_received.emit(message)

func send_action(kind: String, fields: Dictionary = {}) -> Error:
 if capabilities.is_empty() or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
  _error("Local protocol connection is not ready")
  return ERR_UNAVAILABLE
 var message := fields.duplicate(true)
 message["type"] = kind
 message["protocol"] = PROTOCOL
 return socket.send_text(JSON.stringify(message))

func create_room(players: int, timer: int, target: int = 10, picture_filters: Dictionary = {}) -> Error:
 var fields := {"players":players,"timer":timer,"target":target}
 if bool(capabilities.get("picture_filters",false)):
  for key in ["picture_category","picture_difficulty"]:
   if picture_filters.has(key): fields[key]=picture_filters[key]
 if bool(capabilities.get("room_agreement",false)): fields["room_agreement"]=true
 return send_action("duel_create",fields)

func join_room(room_code: String) -> Error:
 var invites=preload("res://scripts/room_invite_code.gd")
 if not invites.valid(room_code):return ERR_INVALID_PARAMETER
 return send_action("duel_join", {"code":invites.normalize(room_code)})

func resume_session() -> Error:
 if code.is_empty() or token.is_empty(): return ERR_UNAVAILABLE
 _resume_requested = true
 return connect_endpoint(endpoint)

func close_transport() -> void:
 _auto_resume=false
 _resume_until=0
 _resume_requested=false
 socket.close()
 capabilities = {}
 connection_changed.emit(false)

func _error(value: String) -> void:
 last_error = value
 error_count += 1

func _exit_tree() -> void:
 var policy=get_tree().root.get_node_or_null("RoomAudioPolicy")
 if policy!=null:policy.membership(self,false)
 socket.close()

# Renew an existing identity; a fresh guest identity must never replace a resume owner.
func _renew_authentication() -> void:
 _renewing=true
 if is_instance_valid(_request): _request.queue_free()
 _request=HTTPRequest.new()
 _request.timeout=15
 _request.body_size_limit=4096
 add_child(_request)
 _request.request_completed.connect(_renewed)
 var url: String=endpoint.replace("wss://","https://").replace("ws://","http://").trim_suffix("/")+"/session/refresh"
 var error: Error=_request.request(url,PackedStringArray(["X-GamingHub-Terms: 1","Authorization: Bearer "+_auth_token]))
 if error!=OK:
  _renewing=false
  _renew_retry_at=Time.get_ticks_msec()+5000

func _renewed(result: int, code_status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
 _renewing=false
 _renew_retry_at=Time.get_ticks_msec()+5000
 if result!=HTTPRequest.RESULT_SUCCESS or code_status!=200: return
 var value: Variant=JSON.parse_string(body.get_string_from_utf8())
 if not value is Dictionary or str(value.get("token","")).is_empty(): return
 _auth_token=str(value.token)
 _auth_expiry=Time.get_ticks_msec()+maxi(0,int(value.get("expires_in",0))-30)*1000
 if socket.get_ready_state()==WebSocketPeer.STATE_OPEN:
  send_action("duel_session_refresh",{"token":_auth_token})
