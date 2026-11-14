extends SceneTree
var folder="user://premium_storyboard"
func _initialize() -> void:call_deferred("run")
func snap(name: String) -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder));root.content_scale_size=Vector2i(360,810)
 var main=load("res://tests/picture_ui_preview.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.ui_tr=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"));main.question_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"));main.load_catalog();main.age_group="18plus";main.reduced_motion=true;main.sound_enabled=false
 main.show_welcome();await snap("story-welcome")
 main.show_home();await snap("story-home")
 main.show_modes(0);await snap("story-picture-modes")
 main.show_player_account();await snap("story-profile")
 var account=main.root.get_children().filter(func(n):return n.get_script()==load("res://scripts/player_account_ui.gd"))[0]
 account._friends_group.show();await snap("story-friends")
 main.show_accessibility();await snap("story-settings")
 main.show_rewards();await snap("story-rewards")
 main.selected_language="en";main.show_welcome();await snap("story-welcome-en")
 print("PREMIUM_STORYBOARD_CAPTURE 360x810 actual Godot; offline guest state, no fabricated users or balance")
 main.queue_free();await process_frame;quit()
