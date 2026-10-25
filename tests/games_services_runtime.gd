extends SceneTree
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
 if not value:
  failures.append(message)
func _initialize() -> void:
 call_deferred("run_checks")
func run_checks() -> void:
 var hub = load("res://scenes/Main.tscn").instantiate()
 root.add_child(hub)
 await process_frame
 hub.show_games_list_v2()
 var texts: Array[String] = []
 collect_buttons(hub, texts)
 check(texts.any(func(t): return "PHOTO DUEL" in t or "تحدي الأصدقاء" in t), "Missing Photo Duel entry")
 check(texts.any(func(t): return "PARTY ROOM" in t or "حفلات الأصدقاء" in t), "Missing Party Room entry")
 hub.queue_free()
 await process_frame
 var party = load("res://scenes/PartyRoomStaging.tscn").instantiate()
 root.add_child(party)
 await process_frame
 party.player_id = "p0"
 party.room_state = {"phase":"active", "round_index":6, "game":"draw_disaster", "host_id":"p0", "members":[{"id":"p0","name":"Host"},{"id":"p1","name":"Friend"}], "round_rule":{"answer_kind":"drawing"},"challenge":{"prompt":"ارسم قطة"},"scores":{}}
 party._room()
 check(is_instance_valid(party.drawing_surface), "No drawing surface")
 party.drawing_surface.strokes = [[[0.1,0.1],[0.8,0.8]]]
 check(JSON.parse_string(party.drawing_surface.payload()).size() == 1, "Drawing serialization")
 party._room()
 check(party.drawing_surface.strokes.size() == 1, "Remote update erased drawing draft")
 party.queue_free()
 await process_frame
 var scroll := preload("res://scripts/touch_scroll.gd").new()
 scroll.size = Vector2(420,400)
 root.add_child(scroll)
 var list := VBoxContainer.new()
 scroll.add_child(list)
 for i in range(30):
  var button := Button.new()
  button.custom_minimum_size = Vector2(400,80)
  list.add_child(button)
 await process_frame
 await process_frame
 var down := InputEventScreenTouch.new()
 down.index = 0
 down.pressed = true
 down.position = Vector2(100,300)
 scroll._input(down)
 var drag := InputEventScreenDrag.new()
 drag.index = 0
 drag.position = Vector2(100,100)
 scroll._input(drag)
 check(scroll.scroll_vertical > 0, "Finger drag did not scroll over controls")
 check(list.get_child(0).disabled, "Drag did not cancel button tap")
 down.pressed = false
 scroll._input(down)
 await process_frame
 check(not list.get_child(0).disabled, "Button remained disabled after drag")
 scroll.queue_free()
 await process_frame
 print("GAMES_SERVICES_RUNTIME failures=", failures.size())
 for failure in failures:
  push_error(failure)
 quit(0 if failures.is_empty() else 1)
func collect_buttons(node: Node, texts: Array[String]) -> void:
 if node is Button:
  texts.append(node.text)
 for child in node.get_children():
  collect_buttons(child,texts)
