extends SceneTree
# Headless scene smoke checks. Run after `godot --headless --editor --import --quit`.
var failures: Array[String] = []
func _initialize() -> void:
 call_deferred("_run")
func _check_scene(path: String) -> void:
 var packed := load(path) as PackedScene
 if packed == null:
  failures.append("Cannot load: " + path)
  return
 var instance := packed.instantiate()
 if instance == null:
  failures.append("Cannot instantiate: " + path)
  return
 root.add_child(instance)
 await process_frame
 await process_frame
 if not is_instance_valid(instance):
  failures.append("Scene destroyed on startup: " + path)
 else:
  instance.queue_free()
 await process_frame
func _check_offline_picture_round() -> void:
 var packed := load("res://scenes/Main.tscn") as PackedScene
 if packed == null:
  failures.append("Cannot load offline picture scene")
  return
 var hub = packed.instantiate()
 root.add_child(hub)
 await process_frame
 # Default all-audiences profile is the only supported audience in this release.
 hub.game = 0
 hub.start_game()
 if hub.my_secret.is_empty() or hub.rival_secret.is_empty():
  failures.append("Offline picture round did not initialize both secret cards")
 elif str(hub.my_secret.get("name", "")).is_empty():
  failures.append("Offline picture round has an empty secret card")
 elif str(hub.my_secret.get("name", "")) == str(hub.rival_secret.get("name", "")):
  failures.append("Offline picture round assigned identical secret cards")
 elif hub.player_candidates.is_empty() or hub.rival_candidates.is_empty():
  failures.append("Offline picture round did not initialize candidates")
 else:
  for card in hub.player_candidates:
   if str(card.get("name", "")) == str(hub.rival_secret.get("name", "")):
    failures.append("Player candidate list contains opponent secret")
    break
  for card in hub.rival_candidates:
   if str(card.get("name", "")) == str(hub.my_secret.get("name", "")):
    failures.append("Rival candidate list contains player secret")
    break
 hub.queue_free()
 await process_frame

func _check_arcade_modes() -> void:
 var scene := load("res://scenes/Main.tscn") as PackedScene
 if scene == null:
  failures.append("Arcade scene missing")
  return
 var hub = scene.instantiate()
 root.add_child(hub)
 await process_frame
 hub.game = 5
 hub.difficulty = 1
 hub.session_length = 10
 hub.match_style = "blitz"
 hub.start_game()
 if hub.round_bank.size() < 5 or not is_instance_valid(hub.blitz_timer):
  failures.append("Blitz did not create 5+ rounds and an active clock")
 else:
  hub.finish_round(true, hub.correct_answer_text(hub.round_bank[0]))
  if hub.blitz_total_bonus <= 0:
   failures.append("Blitz win did not earn a time-based score bonus")
 hub.match_style = "treasure"
 hub.start_game()
 if hub.round_bank.size() < 5:
  failures.append("Treasure trail has fewer than five questions")
 else:
  for index in range(4):
   hub.finish_round(true, hub.correct_answer_text(hub.round_bank[hub.question_index]))
   hub.next_round()
  if hub.treasure_keys != 4 or hub.question_index != 4:
   failures.append("Treasure chest was not reached with four earned keys")
  else:
   hub.claim_treasure("double")
   if hub.treasure_keys != 2 or hub.treasure_doubles != 1 or hub.treasure_claims != 1:
    failures.append("Treasure claim incorrectly charged keys or applied reward")
   else:
    hub.finish_round(true, hub.correct_answer_text(hub.round_bank[hub.question_index]))
    if not hub.treasure_doubled_this_round or hub.treasure_doubles != 0:
     failures.append("Treasure double-points boost was not consumed on correct answer")
 hub.queue_free()
 await process_frame

func _run() -> void:
 _check_picture_library()
 await _check_scene("res://scenes/Main.tscn")
 await _check_scene("res://scenes/Multiplayer.tscn")
 await _check_offline_picture_round()
 await _check_arcade_modes()
 if failures.is_empty():
  print("GODOT_SMOKE_PASS: main, multiplayer, picture library, picture round and arcade modes")
  quit(0)
 else:
  for failure in failures:
   push_error(failure)
  quit(1)

func _check_picture_library() -> void:
 var ai = root.get_node_or_null("DailyAI")
 if ai == null or ai.library_count() != 100:
  failures.append("Expected 100 standalone pictures in DailyAI's bundled library")
  return
 var recent_subjects: Array = []
 for day in ["2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18"]:
  var local_pack: Dictionary = ai._library_daily_pack(day)
  if local_pack.is_empty() or local_pack.get("puzzles", []).size() != 6:
   failures.append("Picture library did not create six puzzles for " + day)
   return
  var today_subjects: Array = []
  var today_categories: Dictionary = {}
  for puzzle in local_pack["puzzles"]:
   if not ResourceLoader.exists(str(puzzle.get("local_image", ""))):
    failures.append("Bundled picture missing: " + str(puzzle.get("library_id", "")))
   var asset: Dictionary = ai._library_row(str(puzzle.get("library_id", "")))
   var subject: String = str(asset.get("subject_key", ""))
   if subject.is_empty() or subject in today_subjects or subject in recent_subjects:
    failures.append("Picture subject repeated within three days: " + subject)
   today_subjects.append(subject)
   today_categories[str(asset.get("category", ""))] = true
  if today_categories.size() != 6:
   failures.append("Picture rotation must contain six categories: " + day)
  recent_subjects.append_array(today_subjects)
  if recent_subjects.size() > 18:
   recent_subjects = recent_subjects.slice(recent_subjects.size() - 18)
