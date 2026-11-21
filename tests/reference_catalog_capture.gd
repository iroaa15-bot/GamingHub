extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.content_scale_size = Vector2i(420,900)
 root.get_node("PublishedContent").busy = true
 var main = load("res://tests/picture_ui_preview.gd").new()
 root.add_child(main)
 main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.ui_tr = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"))
 main.load_catalog(); main.age_group = "18plus"; main.audience = "youth"
 main.sound_enabled = false; main.reduced_motion = true; main.selected_language = "ar"
 main.clear_ui(); main.label("الألعاب", 28)
 var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
 main.root.add_child(grid)
 for index in range(10):
  grid.add_child(load("res://scripts/reference_game_tile.gd").make(main,index,"tiger",false))
 await process_frame; await process_frame
 await RenderingServer.frame_post_draw
 var output := "user://reference-catalog.png"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
 var result := root.get_texture().get_image().save_png(output)
 assert(result == OK)
 print("REFERENCE_CATALOG_CAPTURE_PASS ", output)
 main.queue_free()
 await process_frame
 quit()
