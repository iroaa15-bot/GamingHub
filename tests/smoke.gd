extends SceneTree

var backups: Dictionary = {}

func _initialize() -> void:
 var paths: Array[String] = ["user://audience_preferences.json"]
 for key in ["children", "teens", "youth", "adults", "family"]:
  paths.append("user://progress_v10_" + key + ".json")
 for path in paths:
  backups[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
 call_deferred("verify")

func verify() -> void:
 var hub = load("res://scenes/Main.tscn").instantiate()
 root.add_child(hub)
 var starts: int = 0
 var flows: int = 0
 for key in hub.AUDIENCES:
  hub.select_audience(key)
  hub.profile = {"xp": 0, "wins": 0, "matches": 0, "picture_wins": 0}
  hub.selected_topic = "all"
  for language in ["ar", "en", "tr"]:
   hub.selected_language = language
   hub.show_home()
   hub.show_accessibility()
   for game_index in [1, 2, 3, 4, 5, 6, 7, 9]:
    hub.show_modes(game_index)
    hub.show_topics()
    for level in [1, 2, 3]:
     hub.difficulty = level
     hub.start_game()
     assert(not hub.round_bank.is_empty())
     for item in hub.round_bank:
      assert(key in item["audiences"])
      if key == "children" or key == "family":
       assert("children" in item["audiences"])
     starts += 1
    for entry in hub.eligible_questions(game_index):
     hub.round_bank = [entry.duplicate(true)]
     hub.question_index = 0
     hub.correct_count = 0
     hub.streak = 0
     hub.score = 0
     hub.family_active = false
     hub.show_round()
     var mode: String = str(entry.get("mode", "choice"))
     if mode == "order":
      for i in range(entry["steps_" + language].size()):
       hub.pick_order_step(i)
      hub.submit_order()
     elif mode in ["write", "identity"]:
      hub.submit_written(str(entry["answers_" + language][0]))
     else:
      var choices: Array = entry["choices_" + language]
      hub.select_answer(int(entry["correct"]))
     assert(hub.round_finished)
     assert(hub.correct_count == 1)
     flows += 1
     await process_frame
   hub.start_daily()
   assert(hub.round_bank.size() == 10)
   hub.game = 0
   hub.start_game()
   hub.ask_picture_question(0)
   assert(not hub.rival_candidates.is_empty())
  hub.save_progress()
 # Profiles must not share progress.
 hub.select_audience("children")
 hub.profile["xp"] = 123
 hub.save_progress()
 hub.select_audience("adults")
 hub.profile["xp"] = 456
 hub.save_progress()
 hub.select_audience("children")
 assert(int(hub.profile["xp"]) == 123)
 hub.select_audience("adults")
 assert(int(hub.profile["xp"]) == 456)
 # Topic selection and changing games must not leave an empty stale filter.
 hub.game = 3
 hub.selected_topic = "numbers"
 hub.start_game()
 for item in hub.round_bank:
  assert(item["topic"] == "numbers")
 hub.show_modes(1)
 assert(hub.selected_topic == "all")
 # Equal turn counts, handover screen and independent scores for 2–4 players.
 hub.select_audience("family")
 hub.game = 3
 for size in [2, 3, 4]:
  hub.family_names.clear()
  for i in range(size):
   hub.family_names.append("Player %d" % i)
  hub.start_family_match()
  assert(hub.round_bank.size() % size == 0)
  assert(not hub.family_ready)
  var turns: Array[int] = []
  for i in range(size):
   turns.append(0)
  while hub.question_index < hub.round_bank.size():
   hub.family_ready = true
   hub.show_round()
   turns[hub.family_player] += 1
   hub.finish_round(true, "correct")
   if hub.question_index + 1 >= hub.round_bank.size():
    break
   hub.next_round()
   assert(not hub.family_ready)
  for count in turns:
   assert(count == turns[0])
  for points in hub.family_scores:
   assert(points > 0)
  hub.show_results()
  await process_frame
 hub.select_audience("children")
 var online = load("res://scenes/Multiplayer.tscn").instantiate()
 root.add_child(online)
 online._connect_server()
 assert(online.socket.get_ready_state() == WebSocketPeer.STATE_CLOSED)
 online.queue_free()
 await process_frame
 hub.select_audience("adults")
 online = load("res://scenes/Multiplayer.tscn").instantiate()
 root.add_child(online)
 online._handle({"type": "started", "player_index": 0, "opponent_card": {"name": "Lion"}, "questions": ["Animal?"], "your_turn": true})
 assert(online.card_art.texture != null)
 online._handle({"type": "finished", "cards": ["Lion", "Pizza"]})
 online.queue_free()
 hub.queue_free()
 await process_frame
 for path in backups:
  if backups[path] == null:
   DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))
  else:
   var restored := FileAccess.open(str(path), FileAccess.WRITE)
   restored.store_string(str(backups[path]))
   restored.close()
 print("PASS: %d audience/language/difficulty starts, %d question flows, five isolated profiles, daily filtering, topics and 2–4 player family turns" % [starts, flows])
 quit(0)
