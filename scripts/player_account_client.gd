extends Node
## Optional local/staging account transport. No secrets on disk or production endpoints.
signal changed(route: String, data: Dictionary, ok: bool)
var endpoint := ""
var token := ""
var guest_token := ""
var user: Dictionary = {}
var busy := false
var _route := ""
var _http: HTTPRequest
var _pending_progress: Dictionary = {}
func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--player-portal="):
   var value := arg.trim_prefix("--player-portal=")
   var check := RegEx.new()
   check.compile("^http://127[.]0[.]0[.]1:[0-9]{1,5}$")
   if check.search(value) != null and int(value.get_slice(":",2)) in range(1,65536): endpoint=value
 _http=HTTPRequest.new()
 _http.timeout=10
 add_child(_http)
 _http.request_completed.connect(_completed)
func request(route: String, payload: Dictionary = {}, post: bool = true) -> Error:
 if endpoint.is_empty():
  changed.emit(route,{"error":"خدمة الحسابات غير مفعلة؛ اللعب كضيف محلي متاح. Google/Facebook يحتاجان إعدادات خارجية."},false)
  return ERR_UNCONFIGURED
 if busy: return ERR_BUSY
 var headers := PackedStringArray(["Content-Type: application/json"])
 if not token.is_empty(): headers.append("Authorization: Bearer "+token)
 _route=route
 busy=true
 var error := _http.request(endpoint+route,headers,HTTPClient.METHOD_POST if post else HTTPClient.METHOD_GET,JSON.stringify(payload) if post else "")
 if error!=OK:
  busy=false
  changed.emit.call_deferred(route,{"error":"Account service connection failed"},false)
 return error
func sync_progress(value: Dictionary) -> void:
 if token.is_empty() or bool(user.get("guest",true)): return
 var stats := {}
 for key in ["xp","wins","matches","picture_wins"]: stats[key]=maxi(0,int(value.get(key,0)))
 if busy: _pending_progress=stats
 else: request("/progress",{"progress":stats})
func _completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
 busy=false
 var route := _route
 var parser := JSON.new()
 var parsed: Variant=null
 if result==HTTPRequest.RESULT_SUCCESS and not body.is_empty() and parser.parse(body.get_string_from_utf8())==OK: parsed=parser.data
 var data: Dictionary=parsed if parsed is Dictionary else {"error":"تعذر الاتصال بخدمة الحسابات"}
 var ok := result==HTTPRequest.RESULT_SUCCESS and status>=200 and status<300
 if ok and data.has("token"):
  if bool(user.get("guest",false)): guest_token=token
  token=str(data.token)
  user=data.get("user",{})
 if ok and route=="/me": user=data.get("user",{})
 if route=="/auth/logout" and ok:
  token=""
  guest_token=""
  user={}
 if status==401 and route not in ["/auth/login","/auth/register"]:
  token=""
  user={}
 changed.emit(route,data,ok)
 if not _pending_progress.is_empty() and not token.is_empty():
  var pending := _pending_progress.duplicate()
  _pending_progress.clear()
  request("/progress",{"progress":pending})
