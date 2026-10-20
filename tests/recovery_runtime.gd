extends SceneTree
# Run this unchanged against source AND the final APK's compiled Godot resources.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
func find_button(node: Node, phrase: String) -> Button:
 for child in node.get_children():
  if child is Button and phrase in child.text: return child
  var found: Button = find_button(child, phrase)
  if found != null: return found
 return null
func visible_screen(container: Control, context: String) -> void:
 check(is_instance_valid(container), context + " missing")
 if not is_instance_valid(container): return
 check(container.is_visible_in_tree() and container.modulate.a >= 0.99, context + " transparent/hidden")
 check(container.get_child_count() >= 2, context + " empty")
func frames() -> void:
 await process_frame
 await process_frame
func run() -> void:
 create_timer(90).timeout.connect(func(): push_error("RECOVERY_TIMEOUT"); quit(1))
 var hub = load("res://scenes/Main.tscn").instantiate()
 root.add_child(hub); current_scene = hub
 await frames()
 if not hub.has_method("show_home"): push_error("Main controller missing"); quit(1); return
 hub.age_group = "18plus"; hub.selected_language = "en"; hub.show_home()
 var offline: Button = find_button(hub, "PLAY VS COMPUTER")
 check(offline != null, "Computer button missing")
 if offline != null: offline.pressed.emit()
 visible_screen(hub.root, "Computer entry before animation")
 check(hub.game == 0, "Computer entry chose wrong mode")
 hub.difficulty = 2; hub.start_game()
 check(not hub.my_secret.is_empty() and not hub.rival_secret.is_empty(), "Computer cards missing")
 check(hub.card_texture(str(hub.my_secret.name)) != null, "Texture missing")
 hub.ask_picture_question(0)
 check(hub.rival_turn_count > 0, "Computer deduction did not execute")
 for game_index in range(hub.GAMES.size()):
  for level in [1, 2, 3]:
   hub.show_modes(game_index); hub.difficulty = level; hub.match_style = "classic"; hub.start_game()
   visible_screen(hub.root, "Game %d difficulty %d" % [game_index, level])
   if game_index in [1, 2, 3, 5, 6, 7, 9]:
    check(not hub.round_bank.is_empty(), "Quiz bank empty")
    if not hub.round_bank.is_empty():
     hub.finish_round(true, hub.correct_answer_text(hub.round_bank[hub.question_index]))
     check(hub.round_finished and hub.correct_count == 1, "Quiz scoring failed")
     await create_timer(0.33).timeout
   await frames()
 for style in ["classic", "survival", "rival", "chaos", "blitz", "treasure", "vault", "championship"]:
  hub.game = 5; hub.match_style = style; hub.start_game()
  visible_screen(hub.root, "Style " + style)
  check(not hub.round_bank.is_empty(), "Style question bank empty")
  await frames()
 hub.profile["xp"] = 4567; hub.profile["wins"] = 23; hub.profile["coins"] = 321
 hub.save_progress(); hub.load_upgrade()
 check(int(hub.profile.xp) == 4567 and int(hub.profile.wins) == 23 and int(hub.profile.coins) == 321, "Progress changed after reload")
 hub.show_home()
 var friend: Button = find_button(hub, "PLAY WITH A FRIEND")
 check(friend != null, "Friend button missing")
 if friend == null: quit(1); return
 friend.pressed.emit(); await scene_changed; await frames()
 var online = current_scene
 if not online.has_method("_request_action"): push_error("Multiplayer controller missing"); quit(1); return
 visible_screen(online.output, "Friend lobby")
 check(online.output.size.x > 0 and online.output.size.y > 0, "Friend layout collapsed")
 check(is_instance_valid(online.create_button) and is_instance_valid(online.join_button) and is_instance_valid(online.match_button), "Room controls missing")
 check("bridge_available=" in online._voice_diagnostics_text(), "Voice diagnostics failed")
 online._exit_to_games(); await scene_changed; await frames()
 check(int(current_scene.profile.get("xp", 0)) == 4567, "Return from room reset progress")
 current_scene.queue_free(); await frames()
 if failures.is_empty():
  print("RECOVERY_RUNTIME_PASS: actual computer/friend buttons, opacity, textures, computer turn, 10 games x3 levels, quiz scoring, 8 styles, save reload and return")
  quit(0)
 else:
  for failure in failures: push_error(failure)
  quit(1)
