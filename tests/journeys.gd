extends SceneTree

var backups: Dictionary = {}

func _initialize() -> void:
 var paths: Array[String] = ["user://audience_preferences.json"]
 for key in ["children", "teens", "youth", "adults", "family"]:
  paths.append("user://progress_v10_" + key + ".json")
 for path in paths:
  backups[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
 call_deferred("verify")

func answer_correctly(hub) -> void:
 var item: Dictionary = hub.round_bank[hub.question_index]
 var mode: String = str(item.get("mode", "choice"))
 if mode == "order":
  for i in range(item["steps_" + hub.selected_language].size()):
   hub.pick_order_step(i)
  hub.submit_order()
 elif mode in ["write", "identity"]:
  hub.submit_written(str(item["answers_" + hub.selected_language][0]))
 else:
  hub.select_answer(int(item["correct"]))

func verify() -> void:
 var hub = load("res://scenes/Main.tscn").instantiate()
 root.add_child(hub)
 hub.select_audience("adults")
 var scene_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaigns.json"))
 assert(scene_data["scenes"].size() == 5)
 for path in scene_data["scenes"]:
  var scene_texture: Texture2D = load(str(path)) as Texture2D
  assert(scene_texture != null)
  assert(maxi(scene_texture.get_width(), scene_texture.get_height()) <= 768)
 var old_file := FileAccess.open(hub.profile_path(), FileAccess.WRITE)
 old_file.store_string(JSON.stringify({"session_length":3,"language":"tr","session_version":0}))
 old_file.close()
 hub.profile.clear()
 hub.load_upgrade()
 assert(hub.session_length == 15)
 hub.session_length = 20
 hub.save_progress()
 hub.load_upgrade()
 assert(hub.session_length == 20)
 for group in hub.AUDIENCES:
  hub.select_audience(group)
  hub.selected_campaign = "island"
  hub.show_modes(4)
  hub.start_game()
  assert(hub.round_bank.size() == 30)
 hub.select_audience("children")
 hub.session_length = 10
 for index in [1, 2, 3, 5, 6, 7, 9]:
  hub.show_modes(index)
  hub.difficulty = 1
  hub.start_game()
  if hub.round_bank.size() != 10:
   print("SHORT CHILD SESSION: game=", index, " eligible=", hub.eligible_questions(index).size(), "actual=", hub.round_bank.size(), "audience=", hub.audience)
  assert(hub.round_bank.size() == 10)
 hub.select_audience("adults")
 hub.session_length = 20
 for index in [1, 2, 3, 5, 6, 7, 9]:
  hub.show_modes(index)
  hub.start_game()
  assert(hub.round_bank.size() == 20)
  var ids: Array = []
  for item in hub.round_bank:
   assert(item["id"] not in ids)
   ids.append(item["id"])
 # Resume the connected campaign after saving and creating a fresh scene.
 hub.profile.erase("checkpoint_island")
 hub.show_modes(4)
 hub.selected_campaign = "island"
 hub.start_game()
 for i in range(7):
  hub.show_round()
  answer_correctly(hub)
  if i < 6:
   hub.next_round()
 assert(hub.profile["checkpoint_island"]["next"] == 7)
 var saved_score: int = hub.score
 hub.show_home()
 var fresh = load("res://scenes/Main.tscn").instantiate()
 root.add_child(fresh)
 fresh.show_modes(4)
 fresh.start_game()
 assert(fresh.question_index == 7 and fresh.score == saved_score and fresh.correct_count == 7)
 hub.queue_free()
 await process_frame
 hub = fresh
 for language in ["ar", "en", "tr"]:
  hub.profile.erase("checkpoint_island")
  hub.selected_language = language
  hub.show_modes(4)
  hub.start_game()
  for i in range(30):
   hub.show_round()
   answer_correctly(hub)
   assert(hub.profile["checkpoint_island"]["next"] == i + 1)
   assert(hub.correct_count == i + 1)
   if i + 1 < 30:
    hub.next_round()
   await process_frame
  assert(hub.profile["checkpoint_island"]["completed"])
  var xp: int = int(hub.profile["xp"])
  answer_correctly(hub)
  assert(int(hub.profile["xp"]) == xp)
  hub.show_results()
  hub.start_game()
  assert(hub.question_index == 0 and hub.score == 0)
 # Picture journeys draw different hidden cards and guard the Next action.
 hub.deck = "all"
 hub.session_length = 20
 hub.game = 0
 hub.start_game()
 assert(hub.picture_stage_count == 10)
 var discovered: Array = []
 for i in range(10):
  var name: String = str(hub.my_secret["name"])
  assert(name not in discovered)
  discovered.append(name)
  hub.submit_picture_guess(name)
  assert(hub.picture_done)
  if i < 9:
   hub.next_picture_stage()
   var stage: int = hub.picture_stage
   hub.next_picture_stage()
   assert(hub.picture_stage == stage)
  await process_frame
 # Memory journeys continue through multiple boards and finish at their limit.
 for length in [10, 15, 20, 30]:
  hub.session_length = length
  hub.game = 8
  hub.difficulty = 1
  hub.start_game()
  assert(hub.memory_stage_count == clampi(ceili(length / 4.0), 3, 8))
  for stage in range(1, hub.memory_stage_count + 1):
   assert(hub.memory_stage == stage)
   for i in range(hub.memory_cards.size()):
    if i in hub.memory_matched:
     continue
    var pair: int = -1
    for j in range(i + 1, hub.memory_cards.size()):
     if hub.memory_cards[i] == hub.memory_cards[j]:
      pair = j
      break
    hub.flip_memory(i)
    hub.flip_memory(pair)
   assert(hub.memory_done)
   hub.next_memory_board()
   if stage < hub.memory_stage_count:
    var next_stage: int = hub.memory_stage
    hub.next_memory_board()
    assert(hub.memory_stage == next_stage)
   await process_frame
 # Daily now has ten tasks and still rewards only once per date.
 hub.profile.erase("daily_" + Time.get_date_string_from_system())
 var xp_after_first: int = 0
 for repeat in range(2):
  hub.start_daily()
  assert(hub.round_bank.size() == 10)
  for i in range(10):
   hub.show_round()
   answer_correctly(hub)
   if i < 9:
    hub.next_round()
   await process_frame
  if repeat == 0:
   xp_after_first = int(hub.profile["xp"])
  else:
   assert(int(hub.profile["xp"]) == xp_after_first)
 hub.queue_free()
 await process_frame
 for path in backups:
  if backups[path] == null:
   DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))
  else:
   var file := FileAccess.open(str(path), FileAccess.WRITE)
   file.store_string(str(backups[path]))
   file.close()
 print("PASS: longer unique sessions, migrated defaults, 30-stage campaign in three languages, score/checkpoint reload, milestones, multi-picture/memory journeys and ten-task daily reward guard")
 quit(0)
