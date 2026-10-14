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
 hub.select_audience("adults")
 hub.selected_language = "tr"
 hub.save_progress()
 hub.selected_language = "ar"
 hub.load_upgrade()
 assert(hub.selected_language == "tr")
 assert(hub.game_title(0) == "Kartını Tahmin Et")
 assert(hub.audience_title("children") == "ÇOCUKLAR")
 assert(hub.topic_title("visual") == "Görsel keşfi")
 hub.show_languages()
 assert(hub.tr_ui("اختر اللغة", "CHOOSE LANGUAGE") == "DİL SEÇ")
 assert(hub.card_display("Elephant") == "Fil")
 assert(hub.normal_answer("MİKROSKOP") == hub.normal_answer("mikroskop"))
 assert(hub.normal_answer("Mıknatıs") == hub.normal_answer("MIKNATIS"))
 assert(hub.normal_answer("KÜTÜPHANE") == hub.normal_answer("kutuphane"))
 for card in hub.CARDS:
  assert(hub.matches_card_guess(str(card["tr"]), card))
  assert(not str(card["fact_tr"]).is_empty())
 for question in hub.QUESTIONS:
  assert(not str(question["tr"]).is_empty())
 for page in range(6):
  hub.show_gallery(page)
  await process_frame
 hub.select_audience("children")
 assert(hub.selected_language == "tr")
 hub.toggle_language()
 assert(hub.selected_language == "ar")
 hub.toggle_language()
 assert(hub.selected_language == "en")
 hub.toggle_language()
 assert(hub.selected_language == "tr")
 hub.select_audience("adults")
 hub.save_progress()
 var online = load("res://scenes/Multiplayer.tscn").instantiate()
 root.add_child(online)
 assert(online.language == "tr")
 online._handle({"type":"started", "player_index":0, "opponent_card":{"name":"Elephant"}, "your_turn":true, "questions":["Animal?"], "questions_ar":["حيوان؟"], "questions_tr":["Hayvan mı?"]})
 assert(online.questions[0] == "Hayvan mı?")
 assert(online.display_card("Elephant") == "Fil")
 online._toggle_language()
 assert(online.questions[0] == "حيوان؟")
 online._toggle_language()
 assert(online.questions[0] == "Animal?")
 online._toggle_language()
 assert(online.questions[0] == "Hayvan mı?")
 online._handle({"type":"question", "text":"Animal?", "text_tr":"Hayvan mı?", "text_ar":"حيوان؟", "answer":true})
 online.queue_free()
 hub.queue_free()
 await process_frame
 for path in backups:
  if backups[path] == null:
   DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))
  else:
   var file := FileAccess.open(str(path), FileAccess.WRITE)
   file.store_string(str(backups[path]))
   file.close()
 print("PASS: Turkish names, topics, saved selection, Turkish dotted/dotless I and accents, three-language cycle, gallery facts and localized online protocol mocks")
 quit(0)
