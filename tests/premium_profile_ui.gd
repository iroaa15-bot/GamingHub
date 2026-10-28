extends SceneTree
var folder="user://premium_profile_captures"
func _initialize() -> void:call_deferred("run")
func snap(name: String) -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder));root.content_scale_size=Vector2i(420,900)
 var main=load("res://tests/picture_ui_preview.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.ui_tr=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"));main.load_catalog();main.age_group="18plus";main.reduced_motion=true
 main.show_player_account();await process_frame
 var account=main.root.get_children().filter(func(n):return n.get_script()==load("res://scripts/player_account_ui.gd"))[0]
 var valid: bool=not account._auth_group.visible and not account.admin.visible
 valid=valid and account._profile_name.text=="ضيف" and int(account._xp_bar.value)==int(main.profile.get("xp",0))%100
 await snap("premium-profile")
 account._friends_group.show();await snap("premium-friends-empty")
 main.show_accessibility();await snap("premium-settings")
 print("PREMIUM_PROFILE_GUEST_ROLES ",valid," no fabricated friends or admin identity")
 main.queue_free();await process_frame;quit(0 if valid else 1)
