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

func _check_home_navigation() -> void:
 var scene := load("res://scenes/Main.tscn") as PackedScene
 if scene == null:
  failures.append("Navigation: Main scene missing")
  return
 var hub = scene.instantiate()
 root.add_child(hub)
 await process_frame
 # Exercise the exact offline button callback path, not only start_game().
 hub.start_guess_offline()
 await process_frame
 await process_frame
 if hub.game != 0 or not is_instance_valid(hub.root):
  failures.append("Navigation: offline entry did not create a mode screen")
 elif hub.root.get_child_count() < 2 or not hub.root.is_visible_in_tree():
  failures.append("Navigation: offline mode is blank/hidden")
 hub.queue_free()
 await process_frame
 # Exercise friend navigation to the real Multiplayer scene and verify UI content.
 var online := load("res://scenes/Multiplayer.tscn") as PackedScene
 if online == null:
  failures.append("Navigation: Multiplayer scene missing")
  return
 var client = online.instantiate()
 root.add_child(client)
 await process_frame
 await process_frame
 if not is_instance_valid(client) or not is_instance_valid(client.output):
  failures.append("Navigation: Multiplayer did not build its UI")
 elif client.output.get_child_count() < 5 or not client.output.is_visible_in_tree():
  failures.append("Navigation: Multiplayer screen is blank/hidden")
 client.queue_free()
 await process_frame

func _run() -> void:
 await _check_home_navigation()
 await _check_scene("res://scenes/Main.tscn")
 await _check_scene("res://scenes/Multiplayer.tscn")
 await _check_offline_picture_round()
 await _check_arcade_modes()
 if failures.is_empty():
  print("GODOT_SMOKE_PASS: main, multiplayer, picture round and arcade modes")
  quit(0)
 else:
  for failure in failures:
   push_error(failure)
  quit(1)
