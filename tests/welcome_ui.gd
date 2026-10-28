extends SceneTree
var folder="user://welcome_captures"
var failures=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,name: String) -> void:
 print("WELCOME_CHECK ",name," ",ok)
 if not ok:failures.append(name)
func find_action(node: Node,key: String) -> Button:
 if node is Button and node.get_meta("welcome_action","")==key:return node
 for child in node.get_children():
  var found=find_action(child,key)
  if found!=null:return found
 return null
func snap(name: String) -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.content_scale_size=Vector2i(420,900)
 var main=load("res://tests/picture_ui_preview.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.ui_tr=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"));main.question_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"));main.load_catalog();main.age_group="18plus";main.sound_enabled=false;main.reduced_motion=true
 var before=main.profile.duplicate(true)
 main.show_welcome()
 check(find_action(main,"guest")!=null and not find_action(main,"guest").disabled,"guest available")
 check(find_action(main,"google").disabled and find_action(main,"facebook").disabled,"OAuth unavailable clearly")
 check(main.layout_direction==Control.LAYOUT_DIRECTION_RTL,"Arabic RTL")
 await snap("welcome-ar")
 main._welcome_guest();await process_frame
 check(find_action(main,"guest")==null and main.profile==before,"guest opens games without resetting progress")
 main.selected_language="en";main.show_welcome();await snap("welcome-en")
 check(main.layout_direction==Control.LAYOUT_DIRECTION_LTR,"English LTR")
 root.size=Vector2i(360,640);await process_frame;main.show_welcome();await snap("welcome-small")
 check(find_action(main,"guest").size.y>=48,"touch target minimum")
 main.queue_free();await process_frame
 print("WELCOME_FLOW_UI ",failures.is_empty())
 quit(0 if failures.is_empty() else 1)
