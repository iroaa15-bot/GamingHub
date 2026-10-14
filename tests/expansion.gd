extends SceneTree

func _initialize() -> void:
 call_deferred("verify")

func verify() -> void:
 var hub = load("res://scenes/Main.tscn").instantiate()
 root.add_child(hub)
 hub.audience = "adults"
 hub.profile = {"xp": 0, "missed": [], "favorites": []}
 # Tests below keep changes in memory rather than overwriting user profiles.
 hub.audience = ""
 assert(hub.CARDS.size() == 24)
 assert(hub.QUESTIONS.size() == 36)
 for card in hub.CARDS:
  assert(hub.matches_card_guess(str(card["ar"]), card))
  assert(hub.matches_card_guess(str(card["en"]), card))
  for alias in card.get("aliases", []):
   assert(hub.matches_card_guess(str(alias), card))
  for style in ["realistic", "illustration"]:
   hub.art_style = style
   assert(hub.card_texture(str(card["name"])) != null)
 for page in range(6):
  hub.show_gallery(page)
  await process_frame
 hub.game = 5
 var visual: Dictionary = {}
 for item in hub.question_bank["5"]:
  if item.has("image"):
   visual = item
   break
 assert(not visual.is_empty())
 hub.round_bank = [visual.duplicate(true), visual.duplicate(true)]
 hub.question_index = 0
 hub.show_round()
 hub.select_answer((int(visual["correct"]) + 1) % 4)
 assert(str(visual["id"]) in hub.profile["missed"])
 assert(not hub.answer_feedback.is_empty())
 hub.show_round()
 hub.select_answer(int(visual["correct"]))
 assert(str(visual["id"]) not in hub.profile["missed"])
 hub.toggle_favorite()
 assert(5 in hub.profile["favorites"])
 hub.toggle_favorite()
 assert(5 not in hub.profile["favorites"])
 hub.game = 0
 hub.start_picture_game()
 for page in range(6):
  hub.picture_question_page = page
  hub.show_picture_game()
  await process_frame
 hub.queue_free()
 await process_frame
 print("PASS: 24 image cards in both styles, bilingual aliases, six gallery/question pages, wrong-answer feedback, review removal and favorites")
 quit(0)
