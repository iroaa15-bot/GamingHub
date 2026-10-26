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
var last_error := ""
var error_count := 0
var _previous := WebSocketPeer.STATE_CLOSED
var _resume_requested := false
var _started_at := 0

static func allowed_endpoint(value: String) -> bool:
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
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--duel-local="):
   var value := arg.trim_prefix("--duel-local=")
   return value if allowed_endpoint(value) else ""
 return ""

func connect_endpoint(value: String) -> Error:
 if not allowed_endpoint(value):
  _error("Only an explicit loopback/private LAN endpoint is allowed")
  return ERR_INVALID_PARAMETER
 socket.close()
 endpoint = value
 capabilities = {}
 socket = WebSocketPeer.new()
 _previous = WebSocketPeer.STATE_CLOSED
 _started_at = Time.get_ticks_msec()
 var result := socket.connect_to_url(endpoint)
 if result != OK: _error("Connection failed: " + str(result))
 return result

func _process(_delta: float) -> void:
 socket.poll()
 var current := socket.get_ready_state()
 if current == WebSocketPeer.STATE_OPEN:
  if _previous != WebSocketPeer.STATE_OPEN:
   socket.send_text(JSON.stringify({"type":"duel_hello","protocol":PROTOCOL}))
  while socket.get_available_packet_count() > 0:
   var value: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
   if value is Dictionary: _received(value)
 elif current == WebSocketPeer.STATE_CLOSED and _previous != WebSocketPeer.STATE_CLOSED:
  capabilities = {}
  connection_changed.emit(false)
 if current == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() - _started_at > 10000:
  close_transport()
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
   connection_changed.emit(true)
   protocol_ready.emit(message)
   if _resume_requested:
    _resume_requested = false
    send_action("duel_resume", {"code":code,"token":token})
  "duel_created", "duel_joined", "duel_resumed":
   code = str(message.get("code", ""))
   token = str(message.get("token", ""))
   player = int(message.get("player", -1))
  "duel_state":
   if str(message.get("code", "")) == code:
    state = message
    if bool(state.get("closed",false)):
     token = ""
     code = ""
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

func create_room(players: int, timer: int, target: int = 10) -> Error:
 return send_action("duel_create", {"players":players,"timer":timer,"target":target})

func join_room(room_code: String) -> Error:
 return send_action("duel_join", {"code":room_code.strip_edges().to_upper()})

func resume_session() -> Error:
 if code.is_empty() or token.is_empty(): return ERR_UNAVAILABLE
 _resume_requested = true
 return connect_endpoint(endpoint)

func close_transport() -> void:
 socket.close()
 capabilities = {}
 connection_changed.emit(false)

func _error(value: String) -> void:
 last_error = value
 error_count += 1

func _exit_tree() -> void:
 socket.close()
