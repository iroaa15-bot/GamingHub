extends RefCounted
## Pure home-screen catalog and feature gate. No changes to existing navigation.
const FLAG_PATH := "user://home_layout_v2_enabled.json"

static func enabled() -> bool:
 if not FileAccess.file_exists(FLAG_PATH):
  return true
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLAG_PATH))
 return parsed is Dictionary and parsed.get("enabled", false) == true

static func set_enabled(value: bool) -> bool:
 var file := FileAccess.open(FLAG_PATH, FileAccess.WRITE)
 if file == null:
  return false
 file.store_string(JSON.stringify({"enabled": value}))
 file.close()
 return true

static func catalog() -> Array[Dictionary]:
 return [
  {"id": "guess_your_picture", "ar": "خمن صورتك", "en": "Guess Your Picture", "primary": true, "available": true},
  {"id": "party_room", "ar": "حفلات الأصدقاء", "en": "Party Room", "primary": false, "available": false}
 ]

static func party_games() -> Array[Dictionary]:
 return [
  {"id": "pass_the_bomb", "ar": "القنبلة الدوارة", "en": "Pass the Bomb"},
  {"id": "whos_most_likely", "ar": "مين فينا؟", "en": "Who's Most Likely"},
  {"id": "odd_one_out", "ar": "مين المختلف؟", "en": "Odd One Out"},
  {"id": "truth_or_dare", "ar": "حقيقة ولا تحدي", "en": "Truth or Dare"},
  {"id": "draw_disaster", "ar": "ارسم الكارثة", "en": "Draw Disaster"},
  {"id": "crazy_emoji", "ar": "إيموجي مجنون", "en": "Crazy Emoji"},
  {"id": "fake_it", "ar": "كدبة مقنعة", "en": "Fake It"},
  {"id": "secret_mission", "ar": "المهمة السرية", "en": "Secret Mission"}
 ]

static func visible_games(legacy_games: Array[Dictionary], party_ready: bool = false) -> Array[Dictionary]:
 var result: Array[Dictionary] = legacy_games.duplicate(true)
 if party_ready:
  result.append(catalog()[1])
 return result
