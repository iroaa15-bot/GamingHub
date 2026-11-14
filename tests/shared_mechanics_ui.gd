extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var ui=load("res://scripts/shared_quiz_ui.gd")
 if ui==null:quit(1);return
 for game in ["2","7","9"]:
  ui.selected_game=game
  var screen=ui.new();root.add_child(screen)
  await process_frame
  if not is_instance_valid(screen.written_field) or not is_instance_valid(screen.order_submit):quit(1);return
  screen.queue_free();await process_frame
 print("ORIGINAL_MECHANIC_UI_PARSE_PASS")
 quit()
