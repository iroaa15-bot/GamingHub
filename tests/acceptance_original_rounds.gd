extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 create_timer(90).timeout.connect(func(): print("FAIL offline acceptance timeout"); quit(2))
 var app: Variant = load("res://scenes/Main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 # Exercise original game rules without writing to the user's progress file.
 app.audience = ""
 app.profile = app.profile.duplicate(true)
 app.age_group = "18plus"
 app.sound_enabled = false
 app.reduced_motion = true
 app.game = 0
 app.deck = "all"
 var passed := 0
 for card in app.CARDS:
  app.picture_order = [card]
  app.picture_stage = 1
  app.picture_stage_count = 1
  app.build_picture_stage()
  if str(app.my_secret.name) != str(card.name):
   print("FAIL wrong card assigned ",card.name)
   quit(1)
   return
  app.submit_picture_guess(str(card.en))
  if not app.picture_done or not app.picture_recorded:
   print("FAIL actual round did not accept correct guess ",card.name)
   quit(1)
   return
  passed += 1
  await process_frame
 print("PASS original engine build_picture_stage + submit_picture_guess completed ",passed," / 200 actual offline card rounds")
 print("No user progress saved; this is engine verification, not Android acceptance")
 quit(0 if passed == 200 else 1)
