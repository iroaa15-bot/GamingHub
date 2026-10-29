extends SceneTree
var folder=""
func _initialize():call_deferred("run")
func snap(name: String):
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run():
 create_timer(15).timeout.connect(func():quit(2))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(folder);root.content_scale_size=Vector2i(360,810)
 var main=load("res://tests/picture_ui_preview.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.ui_tr=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"));main.load_catalog();main.age_group="18plus";main.sound_enabled=false;main.reduced_motion=true
 main.show_home()
 var primary=main.root.get_node("UnifiedGameCatalog");var more=main.root.get_node("MoreOriginalGames")
 assert(primary.get_child_count()==6 and more.get_child_count()==4 and not more.visible)
 var ids=[]
 for catalog in [primary,more]:
  for tile in catalog.get_children():ids.append(tile.get_meta("game_id"))
 assert(ids==[0,1,6,3,8,9,2,4,5,7])
 for id in range(10):assert(ids.count(id)==1)
 var skin=load("res://scripts/visual_skin.gd")
 for id in [0,1,6,3,8,9]:
  var texture: Texture2D=skin.game_cover(id)
  assert(texture!=null and texture.get_width()<=256 and texture.get_height()<=256)
  assert(texture.get_image().detect_alpha()!=Image.ALPHA_NONE)
 print("PREMIUM_SIX_RASTER_ICONS_RGBA_256 true")
 await snap("home-primary-six")
 for button in main.root.find_children("*","Button",true,false):
  if button.has_meta("more_original_games"):button.pressed.emit();break
 await process_frame;await process_frame
 assert(more.visible);await snap("home-all-original-games")
 var extra: Button=more.get_child(0).get_child(0).get_child(1)
 extra.pressed.emit();await process_frame;await process_frame
 assert(main.game==2)
 print("PREMIUM_CATALOG_TEN_UNIQUE_MORE_ROUTE true")
 main.queue_free();await process_frame;quit()
