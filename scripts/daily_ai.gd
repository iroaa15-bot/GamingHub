extends Node
## Offline-first additive picture archive. Today's 6 pictures appear at the front.
const BASE_URL := "https://gaminghub-multiplayer.onrender.com/ai_daily"
const CACHE_PATH := "user://daily_pictures_history_v2.json"
const IMAGE_FOLDER := "user://daily_picture_cache"
const LIBRARY_PATH := "res://data/picture_library.json"
const LIBRARY_START := "2026-10-15"
var pack: Array[Dictionary] = []
var item: Dictionary = {}
var texture: Texture2D = null
var current_index: int = 0
var last_error: String = ""
var refreshing: bool = false
var _request_token: int = 0
var _library_rows: Array = []
var _library_date: String = ""
var _day_check: float = 0.0
signal changed

func _ready() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IMAGE_FOLDER))
 _load_library()
 if FileAccess.file_exists(CACHE_PATH):
  var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
  if loaded is Dictionary and loaded.get("packs", null) is Array:
   _merge_packs(loaded["packs"], false)
 _ensure_library_today()
 if not pack.is_empty():
  select_puzzle(0)
 refresh()

func _process(delta: float) -> void:
 _day_check += delta
 if _day_check >= 60.0:
  _day_check = 0.0
  _ensure_library_today()

func _load_library() -> void:
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIBRARY_PATH))
 if parsed is Dictionary and int(parsed.get("schema", 0)) == 1 and parsed.get("items", null) is Array:
  for entry in parsed["items"]:
   if entry is Dictionary and str(entry.get("image", "")).begins_with("res://assets/") and ResourceLoader.exists(str(entry["image"])):
    _library_rows.append(entry)

func library_count() -> int:
 return _library_rows.size()

func _library_row(asset_id: String) -> Dictionary:
 for entry in _library_rows:
  if str(entry.get("id", "")) == asset_id:
   return entry
 return {}

func _library_daily_pack(day: String) -> Dictionary:
 if _library_rows.size() < 6:
  return {}
 var groups: Dictionary = {}
 for entry in _library_rows:
  var subject: String = str(entry.get("subject_key", ""))
  if subject.is_empty():
   continue
  if not groups.has(subject):
   groups[subject] = []
  if str(entry.get("source", "")).begins_with("user_handoff"):
   groups[subject].push_front(entry)
  else:
   groups[subject].append(entry)
 # Curated round-robin order keeps at least four categories in each six-picture day.
 var preferred: Array[String] = ["elephant", "eiffel", "banana", "carrot", "pizza", "apple", "tomato", "chair", "lion", "lighthouse", "guitar", "burger", "dolphin", "bicycle", "pyramids", "cake", "giraffe", "camera", "panda", "football", "taj_mahal", "sushi", "penguin", "strawberry", "tiger", "laptop", "violin"]
 var subjects: Array = []
 for subject in preferred:
  if groups.has(subject):
   subjects.append(subject)
 var remaining: Array = groups.keys()
 remaining.sort()
 for subject in remaining:
  if subject not in subjects:
   subjects.append(subject)
 if subjects.size() < 6:
  return {}
 var start_unix: int = Time.get_unix_time_from_datetime_string(LIBRARY_START + "T00:00:00")
 var day_unix: int = Time.get_unix_time_from_datetime_string(day + "T00:00:00")
 var day_index: int = maxi(0, int((day_unix - start_unix) / 86400))
 var puzzles: Array = []
 for slot in range(6):
  var serial: int = day_index * 6 + slot
  var subject: String = str(subjects[serial % subjects.size()])
  var variants: Array = groups[subject]
  var entry: Dictionary = variants[int(serial / subjects.size()) % variants.size()]
  var row: Dictionary = {
   "schema": 2, "id": "library-%s-%02d" % [day, slot], "date": day,
   "type": "image_guess", "source": "bundled_library", "library_id": entry["id"],
   "category": entry["category"], "category_ar": entry["category_ar"], "category_en": entry["category_en"],
   "title_ar": entry["question_ar"], "title_en": entry["question_en"],
   "difficulty": entry["difficulty"], "image": "library-%s-%02d.png" % [day, slot],
   "local_image": entry["image"], "sha256": entry["sha256"],
   "status": "approved", "answer_verified": true,
   "choices_ar": entry["choices_ar"], "choices_en": entry["choices_en"],
   "correct_index": entry["correct_index"], "xp": 25
  }
  puzzles.append(row)
 return {"schema": 3, "source": "bundled_library", "date_utc": day, "puzzles": puzzles}

func _ensure_library_today() -> void:
 var today: String = Time.get_date_string_from_system(true)
 if _library_date == today or today < LIBRARY_START:
  return
 _library_date = today
 var local_pack: Dictionary = _library_daily_pack(today)
 if not local_pack.is_empty():
  _merge_packs([local_pack], true, true)

func _valid_pack(raw: Variant) -> bool:
 if not raw is Dictionary or int(raw.get("schema", 0)) != 3:
  return false
 var day: String = str(raw.get("date_utc", ""))
 if day.length() != 10 or day < "2026-10-01" or day > Time.get_date_string_from_system(true):
  return false
 var puzzles: Variant = raw.get("puzzles", null)
 if not puzzles is Array or puzzles.size() != 6:
  return false
 var ids: Dictionary = {}
 var is_library: bool = str(raw.get("source", "")) == "bundled_library"
 for puzzle in puzzles:
  if not puzzle is Dictionary:
   return false
  var pid: String = str(puzzle.get("id", ""))
  var name: String = str(puzzle.get("image", ""))
  var sha: String = str(puzzle.get("sha256", ""))
  var prefix: String = "library-" if is_library else "daily-"
  if ids.has(pid) or not pid.begins_with(prefix + day + "-"):
   return false
  ids[pid] = true
  if not name.begins_with(prefix + day + "-") or not name.ends_with(".png") or name.contains("/") or name.contains(".."):
   return false
  if sha.length() != 64 or str(puzzle.get("status", "")) != "approved" or not bool(puzzle.get("answer_verified", false)):
   return false
  if is_library:
   var asset: Dictionary = _library_row(str(puzzle.get("library_id", "")))
   if asset.is_empty() or str(puzzle.get("local_image", "")) != str(asset.get("image", "")) or sha != str(asset.get("sha256", "")):
    return false
  var opts_en: Variant = puzzle.get("choices_en", null)
  var opts_ar: Variant = puzzle.get("choices_ar", null)
  if not opts_en is Array or not opts_ar is Array or opts_en.size() != 4 or opts_ar.size() != 4:
   return false
  var correct: int = int(puzzle.get("correct_index", -1))
  if correct < 0 or correct >= 4:
   return false
 return true

func _merge_packs(incoming: Array, save: bool = true, prefer_latest: bool = false) -> void:
 var by_id: Dictionary = {}
 for old in pack:
  by_id[str(old.get("id", ""))] = old
 for group in incoming:
  if _valid_pack(group):
   for puzzle in group["puzzles"]:
    var key: String = str(puzzle.get("id", ""))
    if not by_id.has(key):
     by_id[key] = puzzle.duplicate(true)
 var values: Array = by_id.values()
 values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
  var day_a: String = str(a.get("date", ""))
  var day_b: String = str(b.get("date", ""))
  if day_a != day_b:
   return day_a > day_b
  var local_a: bool = str(a.get("source", "")) == "bundled_library"
  var local_b: bool = str(b.get("source", "")) == "bundled_library"
  if local_a != local_b:
   return local_a
  return str(a.get("id", "")) > str(b.get("id", ""))
 )
 var previous_id: String = str(item.get("id", ""))
 pack.clear()
 for puzzle in values:
  pack.append(puzzle)
 if save:
  var days: Dictionary = {}
  for puzzle in pack:
   var date_str: String = str(puzzle.get("date", ""))
   var group_key: String = date_str + "|" + str(puzzle.get("source", "server"))
   if not days.has(group_key):
    days[group_key] = []
   days[group_key].append(puzzle)
  var keys: Array = days.keys()
  keys.sort()
  keys.reverse()
  var groups: Array = []
  for key in keys:
   # Only complete daily packs are cached as historical metadata.
   if days[key].size() == 6:
    var parts: PackedStringArray = str(key).split("|")
    groups.append({"schema": 3, "source": parts[1], "date_utc": parts[0], "puzzles": days[key]})
  var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
  if f != null:
   f.store_string(JSON.stringify({"schema": 2, "packs": groups}))
   f.close()
 if not pack.is_empty():
  var selected: int = 0
  if not prefer_latest and not previous_id.is_empty():
   for i in range(pack.size()):
    if str(pack[i].get("id", "")) == previous_id:
     selected = i
     break
  select_puzzle(selected)
 else:
  changed.emit()

func refresh() -> void:
 _ensure_library_today()
 _request_page("")

func load_older() -> void:
 if pack.is_empty():
  refresh()
 else:
  var oldest_day: String = str(pack[-1].get("date", ""))
  _request_page(oldest_day)

func _request_page(before: String) -> void:
 if refreshing:
  return
 refreshing = true
 var req := HTTPRequest.new()
 add_child(req)
 req.timeout = 15.0
 req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
  refreshing = false
  if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 0 and body.size() < 131072:
   var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
   if parsed is Dictionary and int(parsed.get("schema", 0)) == 1 and str(parsed.get("kind", "")) == "image" and parsed.get("packs", null) is Array and parsed["packs"].size() <= 7:
    _merge_packs(parsed["packs"], true, before.is_empty())
    last_error = ""
   else:
    last_error = "Picture history is invalid; saved puzzles remain available."
  else:
   last_error = "Picture server offline; saved puzzles remain available."
  changed.emit()
  req.queue_free()
 )
 var url: String = BASE_URL + "/history.json?days=7"
 if not before.is_empty():
  url += "&before=" + before
 if req.request(url) != OK:
  refreshing = false
  last_error = "Picture request could not be started."
  req.queue_free()

func select_puzzle(index: int) -> void:
 if index < 0 or index >= pack.size():
  return
 current_index = index
 item = pack[index]
 texture = null
 changed.emit()
 _load_picture(str(item["image"]), str(item["sha256"]))

func next_puzzle() -> void:
 if not pack.is_empty():
  select_puzzle((current_index + 1) % pack.size())

func previous_puzzle() -> void:
 if not pack.is_empty():
  select_puzzle((current_index + pack.size() - 1) % pack.size())

func _consume_image(data: PackedByteArray, expected_hash: String) -> bool:
 if data.is_empty() or data.size() > 3000000 or _sha256_hex(data) != expected_hash:
  return false
 var image := Image.new()
 if image.load_png_from_buffer(data) != OK or image.get_width() > 2048 or image.get_height() > 2048:
  return false
 texture = ImageTexture.create_from_image(image)
 return true

func _load_picture(name: String, expected_hash: String) -> void:
 _request_token += 1
 var token: int = _request_token
 if str(item.get("source", "")) == "bundled_library":
  var path: String = str(item.get("local_image", ""))
  var asset: Dictionary = _library_row(str(item.get("library_id", "")))
  if not asset.is_empty() and path == str(asset.get("image", "")) and expected_hash == str(asset.get("sha256", "")):
   texture = load(path) as Texture2D
   last_error = "" if texture != null else "Bundled picture could not load."
  changed.emit()
  return
 var cache_path: String = IMAGE_FOLDER + "/" + name
 if FileAccess.file_exists(cache_path):
  if _consume_image(FileAccess.get_file_as_bytes(cache_path), expected_hash):
   changed.emit()
   return
  DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))
 var req := HTTPRequest.new()
 add_child(req)
 req.timeout = 15.0
 req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
  if token != _request_token:
   req.queue_free()
   return
  if result == HTTPRequest.RESULT_SUCCESS and code == 200 and _consume_image(body, expected_hash):
   var f := FileAccess.open(cache_path, FileAccess.WRITE)
   if f != null:
    f.store_buffer(body)
    f.close()
   last_error = ""
  else:
   last_error = "Picture unavailable. Saved quizzes are still playable."
  changed.emit()
  req.queue_free()
 )
 if req.request(BASE_URL + "/" + name) != OK:
  last_error = "Picture download could not start."
  req.queue_free()

func total_pictures() -> int:
 return pack.size()

func _sha256_hex(data: PackedByteArray) -> String:
 var ctx := HashingContext.new()
 if ctx.start(HashingContext.HASH_SHA256) != OK or ctx.update(data) != OK:
  return ""
 return ctx.finish().hex_encode()
