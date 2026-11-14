extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.content_scale_size=Vector2i(360,810)
 var ui=load("res://scripts/shared_quiz_ui.gd");ui.selected_game="6"
 var screen=ui.new();root.add_child(screen);screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var header=screen._main_column.get_node("CompactHeader")
 var found=false
 for child in header.get_children():
  if child is Label and child.text=="خمن الصوت":found=true
 assert(found)
 var icons=preload("res://scripts/visual_skin.gd")
 for kind in ["player","phone","phone_off","back","settings","chat","list","mic","mic_off"]:
  var texture=icons.menu_icon(kind);assert(texture!=null and texture.get_width()==64)
 await create_timer(.5).timeout;await process_frame;await RenderingServer.frame_post_draw
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture="):root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
 print("NUMERIC_UI_ICONS_TITLE_PASS")
 screen.queue_free();await process_frame;quit()
