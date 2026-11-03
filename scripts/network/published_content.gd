extends Node
## Only the public, validated gameplay projection is used. Local banks stay intact.
signal changed
const Auth = preload("res://scripts/network/gaminghub_auth.gd")
var questions: Dictionary = {}
var media: Dictionary = {}
var busy := false
var next_refresh := 0

func _ready() -> void:
 var auth := Auth.new()
 add_child(auth)
 auth.queue_free()
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
