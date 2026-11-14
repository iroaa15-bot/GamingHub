extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, value: String) -> void:
 print(("PASS " if ok else "FAIL ") + value)
 if not ok: failures.append(value)
func button_exists(node: Node, needle: String) -> bool:
 if node is Button and needle in node.text: return true
 for child in node.get_children():
  if button_exists(child, needle): return true
 return false
func wait_until(predicate: Callable, seconds: float) -> bool:
 var until := Time.get_ticks_msec() + int(seconds * 1000)
 while Time.get_ticks_msec() < until:
  if predicate.call(): return true
  await create_timer(0.05).timeout
 return false
func run() -> void:
 create_timer(150).timeout.connect(func(): print("FAIL acceptance watchdog timeout"); quit(2))
 root.size = Vector2i(420,840)
 var app: Variant = load("res://scenes/Main.tscn").instantiate()
 root.add_child(app)
 current_scene = app
 await process_frame
 app.age_group = "18plus"
 app.selected_language = "en"
 app.show_home()
 check(button_exists(app,"GAMES"),"main UI exposes Games")
 app.show_more_games()
 check(button_exists(app,"GUESS YOUR PICTURE"),"Games exposes Guess Your Picture")
 app.show_modes(0)
 check(button_exists(app,"CREATE / JOIN ROOM"),"Guess Your Picture exposes room entry")
 check(button_exists(app,"PICTURE LIBRARY"),"Guess Your Picture exposes library")
 check(app.CARDS.size() == 200,"gameplay catalog contains 200 original cards")
 var textures := 0
 for card in app.CARDS:
  var texture: Texture2D = app.card_texture(str(card.name))
  if texture != null and texture.get_width() > 0: textures += 1
 check(textures == 200,"all 200 gameplay card textures load in engine")
 app.picture_library_page = 24
 app.show_picture_library()
 check(button_exists(app,"PLAY WITH ALL IMAGES"),"last library page still exposes real game action")
 app.deck = "all"
 app.start_picture_game()
 check(app.my_secret.name != app.rival_secret.name,"offline original game assigns distinct playable cards")
 app.queue_free()
 await process_frame
 var a: Variant = load("res://scenes/Multiplayer.tscn").instantiate()
 var b: Variant = load("res://scenes/Multiplayer.tscn").instantiate()
 root.add_child(a)
 root.add_child(b)
 check(a.voice_button != null and a.voice_label != null,"original room UI includes native voice controls")
 a.create_button.pressed.emit()
 var created: bool = await wait_until(func(): return not a.room_code.is_empty(),60)
 check(created,"actual Godot client creates room on existing production server")
 if created:
  b.code_input.text = a.room_code
  b.join_button.pressed.emit()
  var joined: bool = await wait_until(func(): return not a.opponent_card.is_empty() and not b.opponent_card.is_empty(),30)
  check(joined,"second actual Godot client joins by real room code")
  if joined:
   check(a.room_code == b.room_code,"both real clients bound to same room")
   check(a.card_art.texture != null and b.card_art.texture != null,"both room clients load actual opponent image")
   a._send({"type":"ask", "question":0})
   var moved: bool = await wait_until(func(): return b.my_turn and not a.my_turn,20)
   check(moved,"preset question sends to server and transfers turn")
   check(a.asked_questions.has(0),"server question acknowledgement updates client")
   b._guess_card(a.opponent_card)
   check(await wait_until(func(): return a.finished and b.finished,20),"real guess is validated and match completes on server")
 a.socket.close()
 b.socket.close()
 a.queue_free()
 b.queue_free()
 await process_frame
 print("ANDROID_HARDWARE_BLOCKED; TWO_ANDROID_DEVICES_BLOCKED; VOICE_AUDIO_HARDWARE_BLOCKED")
 print("ACCEPTANCE_DESKTOP_" + ("PASS" if failures.is_empty() else "FAIL"))
 quit(0 if failures.is_empty() else 1)
