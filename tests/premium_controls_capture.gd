extends SceneTree
var folder=""
func _initialize():call_deferred("run")
func snap(name: String):
 await create_timer(.2).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
 root.content_scale_size=Vector2i(360,810)
 var script=load("res://scripts/shared_quiz_ui.gd");script.selected_game="1"
 var room=script.new();root.add_child(room);room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 assert(room.players_field.has_theme_stylebox_override("normal_mirrored"))
 assert(room.target_field.get_line_edit().get_theme_stylebox("normal") is StyleBoxTexture)
 print("PREMIUM_RTL_SELECTORS_AND_SPINBOX true")
 room._settings_body.show();await snap("premium-room-settings")
 room._settings_body.hide();await snap("premium-room-entry")
 room.queue_free();await process_frame;quit()
