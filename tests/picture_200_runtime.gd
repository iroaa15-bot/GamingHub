extends SceneTree
# Real engine verification, isolated from network and release/export workflows.
var failures: Array[String] = []
var selections: int = 0

func check(ok: bool, message: String) -> void:
 if not ok:
  failures.append(message)

func _initialize() -> void:
 call_deferred("run_checks")

func run_checks() -> void:
 var hub = load("res://scenes/Main.tscn").instantiate()
 root.add_child(hub)
 await process_frame
 check(hub.CARDS.size() == 200, "Expected exactly 200 playable core cards")
 for card in hub.CARDS:
  for alias in [card["name"],card["ar"],card["en"],card["tr"]] + card.get("aliases",[]):
   check(hub.matches_card_guess(str(alias),card), "Alias rejected: " + str(card["name"]) + str(alias))
  for other in hub.CARDS:
   if card["name"] != other["name"]:
    check(not hub.matches_card_guess(str(other["en"]),card), "Wrong card accepted: " + str(card["name"]))
 var permutations: Dictionary = {}
 hub.rng.seed = 200
 for attempt in range(1000):
  var order: Array = [0,1,2,3]
  hub.shuffle_items(order)
  permutations[str(order)] = true
 check(permutations.size() == 24, "Actual shuffle failed to produce every permutation")
 var bank: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
 var photos: Array = []
 for q in bank["5"]:
  if str(q["id"]).begins_with("photo_"):
   photos.append(q)
 check(photos.size() == 200, "Expected 200 matching photo identity questions")
 hub.game = 5
 hub.match_style = "classic"
 hub.campaign_active = false
 hub.family_active = false
 hub.daily_match = false
 hub.reduced_motion = true
 for lang in ["ar", "en", "tr"]:
  hub.selected_language = lang
  for q in photos:
   check(hub.card_texture(str(q["image"])) != null, "Missing engine texture: " + str(q["image"]))
   for target in range(4):
    hub.round_bank = [q.duplicate(true)]
    hub.question_index = 0
    hub.round_finished = false
    hub.correct_count = 0
    hub.clear_ui()
    hub.round_choice_grid(q)
    var grid = hub.root.get_child(hub.root.get_child_count() - 1)
    check(grid.get_child_count() == 4, "Wrong rendered option count: " + str(q["id"]))
    var clicked = false
    for option in grid.get_children():
     if option.text == q["choices_" + lang][target]:
      option.pressed.emit()
      clicked = true
      break
    check(clicked, "Missing rendered translated option: " + str(q["id"]) + lang)
    var expected: int = 1 if target == int(q["correct"]) else 0
    check(hub.correct_count == expected, "Wrong selection result: " + str(q["id"]) + lang)
    hub.select_answer(target)
    check(hub.correct_count == expected, "Repeated answer changed result: " + str(q["id"]))
    selections += 1
    if selections % 40 == 0:
     await process_frame
  print("Completed actual choice callbacks for language: ", lang)
 hub.round_finished = false
 hub.select_answer(-1)
 hub.select_answer(4)
 check(not hub.round_finished, "Out-of-range answer accepted")
 hub.game = 0
 hub.deck = "all"
 hub.session_length = 10
 hub.picture_order = hub.CARDS.duplicate(true)
 hub.picture_stage_count = hub.CARDS.size()
 var core_wins: int = 0
 for i in range(hub.CARDS.size()):
  hub.picture_stage = i + 1
  hub.build_picture_stage()
  var expected_card: Dictionary = hub.CARDS[i]
  check(hub.my_secret["name"] == expected_card["name"], "Core secret mapped to wrong card")
  check(hub.my_secret["name"] != hub.rival_secret["name"], "Core rival duplicated secret")
  hub.submit_picture_guess(str(expected_card[["ar","en","tr"][i % 3]]))
  check(hub.picture_done, "Correct core answer did not win: " + str(expected_card["name"]))
  core_wins += 1
  if i % 20 == 0:
   await process_frame
 for attempt in range(20):
  hub.start_picture_game()
  var seen: Dictionary = {}
  for card in hub.picture_order:
   seen[str(card["name"])] = true
  check(seen.size() == 200, "Repeated core deck lost or duplicated cards")
  check(hub.my_secret["name"] != hub.rival_secret["name"], "Identical secret assignments")
  check(hub.matches_card_guess(hub.my_secret["tr"], hub.my_secret), "Turkish answer alias rejected")
  check(hub.matches_card_guess(hub.my_secret["ar"], hub.my_secret), "Arabic answer alias rejected")
  check(hub.matches_card_guess(hub.my_secret["en"], hub.my_secret), "English answer alias rejected")
  await process_frame
 hub.queue_free()
 await process_frame
 print("PICTURE_200_RUNTIME selections=", selections, " core_card_wins=", core_wins, " repeated_core_rounds=20 failures=", failures.size())
 for failure in failures:
  push_error(failure)
 quit(0 if failures.is_empty() else 1)
