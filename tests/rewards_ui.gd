extends SceneTree
var folder="user://rewards_captures"
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder));root.content_scale_size=Vector2i(420,900)
 var main=load("res://tests/picture_ui_preview.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.ui_tr=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"));main.load_catalog();main.age_group="18plus"
 var old: int=int(main.profile.get("coins",0));main._on_earned_ad_reward("Coins",50)
 await process_frame;await process_frame
 var valid: bool=int(main.profile.get("coins",0))==old
 var rewards=main.root.get_children().filter(func(n):return n.get_script()==load("res://scripts/rewards_ui.gd"))[0]
 valid=valid and rewards._hint_buttons.values().all(func(b):return b.disabled)
 rewards._wallet_result("/wallet",{"balance":0,"prices":{"hint":25}},true)
 valid=valid and rewards._hint_buttons.hint.text.ends_with("25")
 main.show_rewards()
 await process_frame;await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join("premium-rewards.png"))
 print("REWARDS_NO_CLIENT_MINT_UI ",valid)
 main.queue_free();await process_frame;quit(0 if valid else 1)

