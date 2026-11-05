extends Node
## Only the public, validated gameplay projection is used. Local banks stay intact.
signal changed
const Auth = preload("res://scripts/network/gaminghub_auth.gd")
var questions: Dictionary = {}
var media: Dictionary = {}
var busy := false
var next_refresh := 0
var settings: Dictionary = {}
var settings_version := 0

func _accept_settings(document: Variant) -> bool:
 # Unknown or malformed remote data always restores the bundled presentation.
 settings = {}
 settings_version = 0
 if not document is Dictionary or document.get("schema") != 1: return false
 if typeof(document.get("version")) not in [TYPE_INT,TYPE_FLOAT] or float(document.version)!=int(document.version) or int(document.version)<0: return false
 var value: Variant = document.get("settings")
 if not value is Dictionary: return false
 for key in ["background", "background_end", "primary"]:
  if not value.get(key) is String: return false
  var pattern := RegEx.new()
  pattern.compile("^#[0-9a-fA-F]{6}$")
  if pattern.search(value[key]) == null: return false
  var luminance: float = Color(value[key]).srgb_to_linear().get_luminance()
  if 1.05 / (luminance + 0.05) < 4.5: return false
 for key in ["font_scale", "home_columns", "primary_count"]:
  if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT]: return false
 if float(value.font_scale) < 0.9 or float(value.font_scale) > 1.25: return false
 if float(value.home_columns) != int(value.home_columns) or int(value.home_columns) not in range(4): return false
 if float(value.primary_count) != int(value.primary_count) or int(value.primary_count) not in range(1,11): return false
 for key in ["game_order", "enabled_games"]:
  var entries: Variant = value.get(key)
  if not entries is Array or entries.is_empty() or entries.size() > 10: return false
  if key == "game_order" and entries.size() != 10: return false
  var seen: Dictionary = {}
  for entry in entries:
   if typeof(entry) not in [TYPE_INT, TYPE_FLOAT] or float(entry) != int(entry) or int(entry) not in range(10): return false
   if seen.has(int(entry)): return false
   seen[int(entry)] = true
 for key in ["title_ar", "title_en", "notice_ar", "notice_en"]:
  if not value.get(key) is String: return false
  if str(value[key]).length() > (80 if key.begins_with("title") else 160): return false
  if key.begins_with("title") and str(value[key]).strip_edges().is_empty(): return false
 if not value.get("show_activities") is bool or not value.get("custom_primary") is bool: return false
 settings = value.duplicate(true)
 settings_version = int(document.get("version",0))
 return true

func catalog_order() -> Array:
 var order: Array = settings.get("game_order",[0,1,6,3,8,9,2,4,5,7])
 var enabled: Array = settings.get("enabled_games",range(10))
 var result: Array = []
 for index in order:
  if index in enabled: result.append(int(index))
 return result

func _ready() -> void:
 refresh.call_deferred()

func _process(_delta: float) -> void:
 if Time.get_ticks_msec() >= next_refresh and not busy: refresh()

func _fetch_public(url: String, maximum: int) -> Array:
 var request := HTTPRequest.new()
 request.timeout = 8
 request.body_size_limit = maximum
 add_child(request)
 if request.request(url) != OK:
  request.queue_free()
  return []
 var response: Array = await request.request_completed
 request.queue_free()
 return response

func refresh() -> void:
 if busy: return
 next_refresh = Time.get_ticks_msec()+60000
 if Auth.session_origin.is_empty(): return
 busy = true
 var origin: String = Auth.session_origin
 var config_response: Array = await _fetch_public(origin+"/api/config",32768)
 if origin != Auth.session_origin:
  busy=false
  return
 if config_response.size()==4 and config_response[0]==HTTPRequest.RESULT_SUCCESS and config_response[1]==200:
  _accept_settings(JSON.parse_string((config_response[3] as PackedByteArray).get_string_from_utf8()))
 else:
  _accept_settings(null)
 var response: Array = await _fetch_public(origin+"/api/content/gameplay",2097152)
 var updated: Dictionary = {}
 var resources: Dictionary = {}
 if response.size()==4 and response[0]==HTTPRequest.RESULT_SUCCESS and response[1]==200:
  var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
  if parsed is Dictionary and parsed.get("schema")==1 and parsed.get("items") is Array and parsed.items.size()<=1000:
   var total_bytes := 0
   for raw in parsed.items:
    if not raw is Dictionary or not _valid(raw): continue
    var item: Dictionary = raw.duplicate(true)
    var id: String = str(item.id)
    if item.has("media"):
     if resources.size()>=32: continue
     if not item.media is Dictionary: continue
     var spec: Dictionary = item.media
     if str(spec.get("path","")) != "/api/content/assets/"+id.trim_prefix("pub_"): continue
     var asset: Array = await _fetch_public(origin+str(spec.path),8388608)
     if asset.size()!=4 or asset[0]!=HTTPRequest.RESULT_SUCCESS or asset[1]!=200: continue
     var bytes: PackedByteArray = asset[3]
     total_bytes += bytes.size()
     if total_bytes>33554432: break
     var digest := HashingContext.new()
     digest.start(HashingContext.HASH_SHA256)
     digest.update(bytes)
     if digest.finish().hex_encode()!=str(spec.get("sha256","")): continue
     var resource: Resource
     if spec.get("kind")=="image":
      var decoded := Image.new()
      var err := ERR_INVALID_DATA
      match str(spec.get("mime","")):
       "image/png": err=decoded.load_png_from_buffer(bytes)
       "image/jpeg": err=decoded.load_jpg_from_buffer(bytes)
       "image/webp": err=decoded.load_webp_from_buffer(bytes)
      if err!=OK or decoded.get_width()>4096 or decoded.get_height()>4096: continue
      resource=ImageTexture.create_from_image(decoded)
      item["image"]=id
     elif spec.get("kind")=="sound" and spec.get("mime")=="audio/wav":
      resource=AudioStreamWAV.load_from_buffer(bytes)
      if resource==null: continue
      item["audio"]=id
     else: continue
     resources[id]=resource
    item.erase("media")
    var game: String = str(item.game_id)
    if not updated.has(game): updated[game]=[]
    updated[game].append(item)
 if origin==Auth.session_origin:
  questions=updated
  media=resources
  changed.emit()
 busy=false

func _valid(item: Dictionary) -> bool:
 if not str(item.get("id","")).begins_with("pub_") or str(item.get("game_id","")) not in ["1","3","5","6"]: return false
 for key in ["level","correct"]:
  if typeof(item.get(key)) not in [TYPE_INT,TYPE_FLOAT]: return false
  if float(item[key]) != float(int(item[key])): return false
 if int(item.get("level",0)) not in [1,2,3] or int(item.get("correct",-1)) not in range(4): return false
 for lang in ["ar","en"]:
  if not item.get(lang) is String or str(item.get(lang,"")).is_empty(): return false
  var choices: Variant=item.get("choices_"+lang)
  if not choices is Array or choices.size()!=4: return false
  var seen: Dictionary={}
  for choice in choices:
   if not choice is String or choice.strip_edges().is_empty(): return false
   seen[choice.strip_edges().to_lower()]=true
  if seen.size()!=4: return false
 return true
