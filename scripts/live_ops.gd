extends Node
## Offline-first live-ops rotation. Config is bundled; remote publishing requires a reviewed backend.
var config: Dictionary = {}
var remote_url: String = "https://gaminghub-multiplayer.onrender.com/liveops/rotation.json"
var _last_date_utc: String = ""
var _refresh_in_flight: bool = false
var _day_check_elapsed: float = 0.0
var _last_attempt_ms: int = -600000
const REFRESH_RETRY_MS: int = 300000
var content_source: String = "bundled"
const CACHE_PATH := "user://liveops_cache.json"
signal content_updated(source: String)

func _ready() -> void:
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://liveops/rotation.json"))
 if data is Dictionary:
  config = data
 var cached: Variant = _read_cache()
 if _valid(cached):
  config = cached
  content_source = "cached"
 _last_date_utc = Time.get_date_string_from_system(true)
 if remote_url.begins_with("https://"):
  refresh_content()

func _process(delta: float) -> void:
 _day_check_elapsed += delta
 if _day_check_elapsed < 60.0:
  return
 _day_check_elapsed = 0.0
 # Check once per minute; a failed request may retry after five minutes.
 var utc_day: String = Time.get_date_string_from_system(true)
 if utc_day != _last_date_utc:
  _last_date_utc = utc_day
  _last_attempt_ms = -600000
  refresh_content()
 elif content_source != "remote" and not _refresh_in_flight:
  refresh_content()

func _read_cache() -> Variant:
 if not FileAccess.file_exists(CACHE_PATH):
  return null
 var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
 if file == null or file.get_length() > 262144:
  return null
 return JSON.parse_string(file.get_as_text())

func _valid(value: Variant) -> bool:
 if not (value is Dictionary) or int(value.get("schema", -1)) != 1:
  return false
 if not (value.get("season", null) is String):
  return false
 for group in ["daily_missions", "weekly_missions"]:
  if not (value.get(group, null) is Array) or value[group].size() > 100:
   return false
  for m in value[group]:
   if not (m is Dictionary) or not (m.get("id", null) is String):
    return false
   if str(m.get("type", "")) not in ["matches", "wins"]:
    return false
   if int(m.get("target", 0)) < 1 or int(m.get("target", 0)) > 1000:
    return false
   if int(m.get("xp", -1)) < 0 or int(m.get("xp", 0)) > 500:
    return false
 if not (value.get("event_rotation", null) is Array) or value["event_rotation"].size() > 52:
  return false
 for e in value["event_rotation"]:
  if not (e is Dictionary) or not (e.get("id", null) is String):
   return false
 return true

func refresh_content() -> void:
 if not remote_url.begins_with("https://") or _refresh_in_flight:
  return
 var now_ms: int = Time.get_ticks_msec()
 if now_ms - _last_attempt_ms < REFRESH_RETRY_MS:
  return
 _last_attempt_ms = now_ms
 _refresh_in_flight = true
 var request := HTTPRequest.new()
 add_child(request)
 request.timeout = 10.0
 request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
  if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() <= 262144:
   var incoming: Variant = JSON.parse_string(body.get_string_from_utf8())
   if _valid(incoming):
    config = incoming
    content_source = "remote"
    var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
    if file != null:
     file.store_string(JSON.stringify(incoming))
    content_updated.emit(content_source)
  _refresh_in_flight = false
  request.queue_free()
 )
 if request.request(remote_url) != OK:
  _refresh_in_flight = false
  request.queue_free()

func day_key() -> String:
 return Time.get_date_string_from_system()
func week_key() -> String:
 var d: Dictionary = Time.get_date_dict_from_system()
 var unix: int = Time.get_unix_time_from_datetime_dict({"year":int(d.year),"month":int(d.month),"day":int(d.day),"hour":12})
 var monday: int = int((unix - 3 * 86400) / 604800)
 return str(monday)
func event_for_week() -> Dictionary:
 var events: Array = config.get("event_rotation", [])
 if events.is_empty():
  return {}
 return events[posmod(int(week_key()), events.size())]
func missions(period: String) -> Array:
 var all: Array = config.get("daily_missions" if period == "daily" else "weekly_missions", [])
 if all.is_empty():
  return []
 var seed: int = hash(day_key() if period == "daily" else week_key())
 var offset: int = posmod(seed, all.size())
 return [all[offset]] if all.size() == 1 else [all[offset], all[(offset + 1) % all.size()]]
func update(profile: Dictionary, won: bool) -> void:
 for period in ["daily", "weekly"]:
  var key: String = day_key() if period == "daily" else week_key()
  var record_key: String = "liveops_" + period
  var record: Dictionary = profile.get(record_key, {})
  if str(record.get("key", "")) != key:
   record = {"key":key,"matches":0,"wins":0,"claimed":[]}
  record["matches"] = int(record.get("matches", 0)) + 1
  if won:
   record["wins"] = int(record.get("wins", 0)) + 1
  profile[record_key] = record
func claim(profile: Dictionary, period: String, mission: Dictionary) -> bool:
 var key: String = day_key() if period == "daily" else week_key()
 var record_key: String = "liveops_" + period
 var record: Dictionary = profile.get(record_key, {})
 if str(record.get("key", "")) != key:
  return false
 var claimed: Array = record.get("claimed", [])
 var id: String = str(mission.get("id", ""))
 if id in claimed or int(record.get(str(mission.get("type", "matches")), 0)) < int(mission.get("target", 0)):
  return false
 claimed.append(id)
 record["claimed"] = claimed
 profile[record_key] = record
 profile["xp"] = int(profile.get("xp", 0)) + int(mission.get("xp", 0))
 return true
