extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.get_node("PublishedContent").busy = true
 var policy=root.get_node("RoomAudioPolicy");policy.set_music_enabled(false);policy.set_effects_enabled(false)
 var main = load("res://tests/picture_ui_preview.gd").new()
 root.add_child(main)
 main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.ui_tr = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"))
 main.load_catalog(); main.age_group = "18plus"; main.audience = "youth"
 main.sound_enabled = false; main.reduced_motion = true
 for language in ["ar", "en"]:
  main.selected_language = language
  for index in range(10):
   main.game = -1; main.clear_ui()
   var tile: PanelContainer = load("res://scripts/reference_game_tile.gd").make(main,index,"tiger",false)
   main.root.add_child(tile)
   var action := tile.get_node("GameAction") as Button
   assert(action != null and action.text == main.game_title(index))
   assert(action.has_meta("reference_game_tile"))
   assert(action.get_node("Content/Caption").text == action.text)
   action.pressed.emit()
   await process_frame; await process_frame
   assert(main.game == index)
 print("REFERENCE_GAME_TILE_PASS: 10 actual routes AR/EN")
 main.queue_free();await process_frame
 quit()
