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
 for group in hub.AUDIENCES:
  hub.select_audience(group)
  for language in ["ar", "en", "tr"]:
   hub.selected_language = language
   hub.show_home()
   for collection in ["all", "Animal", "Food", "Object", "Place"]:
    hub.deck = collection
    hub.show_modes(0)
    hub.show_decks()
    hub.start_picture_game()
    assert(hub.my_secret["name"] != hub.rival_secret["name"])
    assert(hub.player_candidates.size() == hub.deck_cards().size() - 1)
    hub.ask_picture_question(0)
    assert(not hub.player_candidates.is_empty())
    assert(hub.my_secret["name"] in hub.player_candidates.map(func(c): return c["name"]))
    for level in [1, 2, 3]:
     hub.game = 8
     hub.difficulty = level
     hub.start_game()
     assert(hub.memory_cards.size() % 2 == 0)
     assert(hub.memory_cards.size() / 2 == mini(hub.deck_cards().size(), 4 + level * 2))
     var xp_before: int = int(hub.profile.get("xp", 0))
     for i in range(hub.memory_cards.size()):
      if i in hub.memory_matched:
       continue
      var pair: int = -1
      for j in range(i + 1, hub.memory_cards.size()):
       if hub.memory_cards[j] == hub.memory_cards[i]:
        pair = j
        break
      assert(pair >= 0)
      hub.flip_memory(i)
      hub.flip_memory(i)
      assert(hub.memory_open.size() == 1)
      hub.flip_memory(pair)
     assert(hub.memory_done)
     assert(int(hub.profile["xp"]) > xp_before)
     var xp_after: int = int(hub.profile["xp"])
     hub.finish_memory()
     assert(int(hub.profile["xp"]) == xp_after)
     starts += 1
     await process_frame
 # Mismatches stay visible briefly, block extra clicks, and then reset.
 hub.game = 8
 hub.deck = "all"
 hub.start_memory()
 var other: int = 1
 while hub.memory_cards[other] == hub.memory_cards[0]:
  other += 1
 hub.flip_memory(0)
 hub.flip_memory(other)
 assert(hub.memory_busy)
 assert(hub.memory_moves == 1)
 hub.flip_memory((other + 1) % hub.memory_cards.size())
 assert(hub.memory_open.size() == 2)
 await create_timer(1.4).timeout
 assert(not hub.memory_busy and hub.memory_open.is_empty())
 # A pending mismatch must not change a newly started board or a menu.
 hub.flip_memory(0)
 hub.flip_memory(other)
 hub.show_home()
 hub.game = 8
 hub.start_memory()
 hub.flip_memory(0)
 await create_timer(1.4).timeout
 assert(hub.memory_open == [0])
 hub.show_modes(9)
 hub.start_game()
 hub.pick_order_step(0)
 hub.submit_order()
 assert(not hub.round_finished)
 hub.pick_order_step(0)
 assert(hub.order_picks == [0])
 hub.undo_order_step()
 assert(hub.order_picks.is_empty())
 var steps: Array = hub.round_bank[0]["steps_" + hub.selected_language]
 for i in range(steps.size() - 1, -1, -1):
  hub.pick_order_step(i)
 hub.submit_order()
 assert(hub.round_finished and hub.correct_count == 0)
 assert(hub.round_bank[0]["id"] in hub.profile["missed"])
 hub.select_audience("family")
 hub.show_modes(9)
 hub.family_names.assign(["A", "B", "C", "D"])
 hub.start_family_match()
 assert(hub.round_bank.size() % 4 == 0 and not hub.round_bank.is_empty())
 while true:
  hub.family_ready = true
  hub.show_round()
  var item: Dictionary = hub.round_bank[hub.question_index]
  for i in range(item["steps_" + hub.selected_language].size()):
   hub.pick_order_step(i)
  hub.submit_order()
  if hub.question_index + 1 >= hub.round_bank.size():
   break
  hub.next_round()
 for points in hub.family_scores:
  assert(points > 0)
 hub.queue_free()
 await process_frame
 for path in backups:
  if backups[path] == null:
   DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))
  else:
   var file := FileAccess.open(str(path), FileAccess.WRITE)
   file.store_string(str(backups[path]))
   file.close()
 print("PASS: %d memory boards across audiences/languages/decks/difficulties, picture deduction pools, reward-once, mismatch delays/navigation, order undo/incomplete/wrong answers and four-player ordering" % starts)
 quit(0)
