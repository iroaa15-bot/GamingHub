extends Node
## Persistent, additive daily question library. New entries prepend; older packs never vanish.
const BASE_URL := "https://gaminghub-multiplayer.onrender.com/content/history.json"
const CACHE_PATH := "user://daily_rounds_history_v2.json"
const LEGACY_CACHE_PATH := "user://daily_rounds_v1.json"
const MAX_BYTES := 393216
const RETRY_MS := 300000
var current_pack: Dictionary = {}
var history: Array[Dictionary] = []
var source: String = "bundled"
var error_message: String = ""
var refreshing: bool = false
var _last_check: float = 0.0
var _last_attempt_ms: int = -300000
signal changed

func _ready() -> void:
 var cached: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH)) if FileAccess.file_exists(CACHE_PATH) else null
 if cached is Dictionary and cached.get("packs", []) is Array:
  _merge(cached["packs"], false)
 if FileAccess.file_exists(LEGACY_CACHE_PATH):
  var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_CACHE_PATH))
  if _valid_pack(legacy):
   _merge([legacy], false)
 _set_current()
 refresh()

func _process(delta: float) -> void:
 _last_check += delta
 if _last_check < 60.0:
  return
 _last_check = 0.0
 var was_today: bool = not current_pack.is_empty()
 _set_current()
 if was_today and current_pack.is_empty():
  changed.emit()
 if current_pack.is_empty() and not refreshing:
  refresh()

func _valid_pack(raw: Variant) -> bool:
 if not raw is Dictionary or int(raw.get("schema", -1)) != 1:
  return false
 if str(raw.get("source", "")) != "verified_procedural":
  return false
 var date_str: String = str(raw.get("date_utc", ""))
 if date_str.length() != 10 or date_str > Time.get_date_string_from_system(true) or date_str < "2026-10-01":
  return false
 if not raw.get("questions", null) is Array or raw["questions"].size() != 24:
  return false
 var seen: Dictionary = {}
 for item in raw["questions"]:
  if not item is Dictionary or str(item.get("game", "")) not in ["2", "3", "5"] or str(item.get("mode", "")) != "choice":
   return false
  var item_id: String = str(item.get("id", ""))
  if not item_id.begins_with("remote_" + date_str + "_") or seen.has(item_id):
   return false
  seen[item_id] = true
  if int(item.get("level", 0)) < 1 or int(item.get("level", 0)) > 3:
   return false
  for field in ["ar", "en", "explain_ar", "explain_en", "topic"]:
   if not item.get(field, null) is String or str(item[field]).length() < 2 or str(item[field]).length() > 240:
    return false
  for field in ["choices_ar", "choices_en"]:
   var options: Variant = item.get(field, null)
   if not options is Array or options.size() != 4:
    return false
   var distinct: Dictionary = {}
   for option in options:
    if not option is String or option.is_empty() or option.length() > 60 or distinct.has(option):
     return false
    distinct[option] = true
  var correct_index: int = int(item.get("correct", -1))
  if correct_index < 0 or correct_index > 3:
   return false
  if str(item["choices_ar"][correct_index]) != str(item["choices_en"][correct_index]):
   return false
 return true

func _set_current() -> void:
 # The selected pack aliases a history entry; clear() would erase saved history.
 current_pack = {}
 var today: String = Time.get_date_string_from_system(true)
 for data in history:
  if str(data.get("date_utc", "")) == today:
   current_pack = data
   return

func _merge(packs: Array, save: bool = true) -> void:
 var by_date: Dictionary = {}
 for existing in history:
  by_date[str(existing["date_utc"])] = existing
 for incoming in packs:
  if _valid_pack(incoming):
   var key: String = str(incoming["date_utc"])
   if not by_date.has(key):
    by_date[key] = incoming.duplicate(true)
 var dates: Array = by_date.keys()
 dates.sort()
 dates.reverse()
 history.clear()
 for key in dates:
  history.append(by_date[key])
 _set_current()
 if save:
  var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
  if file != null:
   file.store_string(JSON.stringify({"schema": 2, "packs": history}))
   file.close()
  changed.emit()

func total_questions() -> int:
 return history.size() * 24

func refresh(force: bool = false) -> void:
 _request_page("", force)

func load_older() -> void:
 if history.is_empty():
  refresh(true)
 else:
  _request_page(str(history[-1].get("date_utc", "")), true)

func _request_page(before: String, force: bool) -> void:
 if refreshing:
  return
 var now: int = Time.get_ticks_msec()
 if not force and now - _last_attempt_ms < RETRY_MS:
  return
 _last_attempt_ms = now
 refreshing = true
 var req := HTTPRequest.new()
 req.timeout = 15.0
 add_child(req)
 req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
  refreshing = false
  if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 0 and body.size() <= MAX_BYTES:
   var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
   if parsed is Dictionary and int(parsed.get("schema", 0)) == 1 and str(parsed.get("kind", "")) == "text" and parsed.get("packs", null) is Array and parsed["packs"].size() <= 7:
    _merge(parsed["packs"])
    source = "server"
    error_message = ""
   else:
    error_message = "Daily history rejected. Saved content is still available."
  else:
   error_message = "Daily server offline; previously saved questions remain available."
  req.queue_free()
 )
 var url: String = BASE_URL + "?days=7"
 if not before.is_empty():
  url += "&before=" + before
 if req.request(url, PackedStringArray(["Accept: application/json"])) != OK:
  refreshing = false
  error_message = "Could not start daily history request."
  req.queue_free()
