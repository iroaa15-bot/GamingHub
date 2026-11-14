extends SceneTree
var failures=[]
var folder="user://main_flow_captures"
func _initialize() -> void:call_deferred("run")
func buttons(node: Node) -> Array:
 var result=[]
 if node is Button:result.append(node)
 for child in node.get_children():result.append_array(buttons(child))
 return result
func snap(name: String) -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func check(ok: bool,name: String) -> void:
 print("MAIN_UI ",name," ",ok)
 if not ok:failures.append(name)
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.content_scale_size=Vector2i(420,900)
 var main=load("res://tests/picture_ui_preview.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.ui_tr=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"));main.question_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"));main.load_catalog();main.age_group="18plus";main.sound_enabled=false;main.reduced_motion=true
 var original_difficulty=main.difficulty
 main.show_modes(0)
 var labels=[]
 for b in buttons(main):labels.append(b.text)
 check(not labels.has(main.difficulty_name(1)) and not labels.has(main.difficulty_name(2)) and not labels.has(main.difficulty_name(3)),"no duplicate easy medium hard on picture mode page")
 check(main.difficulty==original_difficulty,"existing offline round rules unchanged")
 check(labels.has("ابدأ اللعب بدون إنترنت"),"offline play remains accessible")
 await snap("picture-main-refined")
 main.show_modes(1);labels=[]
 for b in buttons(main):labels.append(b.text)
 check(labels.has(main.difficulty_name(1)) and labels.has(main.difficulty_name(2)) and labels.has(main.difficulty_name(3)),"other game difficulty controls preserved")
 main.queue_free();await process_frame
 print("MAIN_PICTURE_FLOW_UI ",failures.is_empty())
 quit(0 if failures.is_empty() else 1)
