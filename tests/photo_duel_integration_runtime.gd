extends SceneTree
var failed := false
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 print(("PASS " if ok else "FAIL ") + message)
 if not ok: failed = true
func find_button(node: Node, needle: String) -> Button:
 if node is Button and needle.to_lower() in node.text.to_lower(): return node
 for child in node.get_children():
  var result := find_button(child, needle)
  if result != null: return result
 return null
func touch(b: Button) -> void:
 var at := b.get_global_rect().get_center()
 var down := InputEventScreenTouch.new()
 down.position = at
 down.pressed = true
 Input.parse_input_event(down)
 var up := InputEventScreenTouch.new()
 up.position = at
 up.pressed = false
 Input.parse_input_event(up)
func run() -> void:
 root.size = Vector2i(420,840)
 Input.emulate_mouse_from_touch = true
 var main: Variant = load("res://scenes/Main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 await process_frame
 main.selected_language = "en"
 main.age_group = "18plus"
 main.show_home()
 await process_frame
 var entry := find_button(main,"PHOTO DUEL")
 check(entry != null,"original main UI exposes Photo Duel")
 # Exercise actual touch input on the shared original button helper repeatedly.
 for i in range(20):
  var b: Button = main.button("TOUCH TEST",main.show_home)
  await process_frame
  b.grab_focus()
  var scroll: ScrollContainer = main.root.get_parent().get_parent()
  scroll.ensure_control_visible(b)
  await process_frame
  await process_frame
  var generation: int = main.ui_action_generation
  touch(b)
  await process_frame
  await process_frame
  check(main.ui_action_generation == generation + 1, "touch navigation %d" % i)
  await process_frame
  await process_frame
 check(main.is_inside_tree(),"20 real ScreenTouch main button navigations")
 main.open_photo_duel()
 await process_frame
 await process_frame
 var duel: Variant = current_scene
 check(duel.get_script().resource_path.ends_with("photo_duel_network_staging.gd"),"navigation uses embedded Photo Duel")
 check(duel.server_url == "wss://gaminghub-multiplayer.onrender.com","same existing room endpoint")
 duel.language = "en"
 duel._draw_lobby()
 await process_frame
 check(find_button(duel,"Create room") != null,"English lobby")
 duel.language = "ar"
 duel._draw_lobby()
 await process_frame
 check(find_button(duel,"إنشاء غرفة") != null,"Arabic lobby")
 var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guess_picture_302/catalog.json"))
 var count := 0
 for item in catalog.items:
  if item.group == "original_200": count += 1
 check(count == 200,"exact original 200 catalog selection")
 duel._received({"type":"photo_question", "mode":"tap", "question_id":"animal", "answer":true})
 check("نعم" in duel.last_feedback and "حيوان" in duel.last_feedback, "tap question displays its answer")
 duel._received({"type":"photo_reply", "answer":false})
 check("لا" in duel.last_feedback, "opponent reply displays No")
 duel._draw_lobby()
 var stale := find_button(duel,"إنشاء غرفة")
 stale.pressed.emit()
 duel._draw_lobby()
 await process_frame
 check(duel.socket.get_ready_state() == WebSocketPeer.STATE_CLOSED,"stale button cannot create room")
 duel._home()
 await process_frame
 await process_frame
 check(current_scene.scene_file_path == "res://scenes/Main.tscn","return to original main application")
 print("INTEGRATION_RUNTIME_" + ("FAIL" if failed else "PASS"))
 quit(1 if failed else 0)
