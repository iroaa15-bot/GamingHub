extends SceneTree
## Native rendering coverage; seeded UI states are not full Android match acceptance.
var folder := "user://core-reference"
var captures := 0
func _initialize() -> void:call_deferred("run")
func snap(key: String) -> void:
 await process_frame;await process_frame
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(folder.path_join(key+".png"))==OK)
 captures+=1
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.content_scale_size=Vector2i(420,900)
 root.get_node("PublishedContent").busy=true
 root.get_node("GamingHubAccount").api_base=""
 var policy=root.get_node("RoomAudioPolicy");policy.set_music_enabled(false);policy.set_effects_enabled(false)
 var main=load("res://tests/picture_ui_preview.gd").new();root.add_child(main)
 main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.ui_tr=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"))
 main.question_bank=load("res://scripts/approved_content.gd").questions(JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json")))
 main.load_catalog();main.age_group="18plus";main.audience="youth"
 main.sound_enabled=false;main.reduced_motion=true;main.session_length=5
 for language in ["ar","en"]:
  main.selected_language=language
  for id in range(10):
   var prefix="core-%02d-%s"%[id,language]
   main.show_modes(id);await snap(prefix+"-mode")
   var route_count:=0
   for button in main.root.find_children("*","Button",true,false):
    if button.has_meta("mode_action"):route_count+=1
   assert(route_count==3)
   main.game=id;main.match_style="classic";main.selected_topic="all"
   main.rng.seed=231119+id
   main.start_game();await snap(prefix+"-play")
   if id not in [0,8] and not main.round_bank.is_empty():
    var item: Dictionary=main.round_bank[main.question_index]
    var answer: String=str(item.get(language,item.get("en","")))
    main.finish_round(true,answer);await snap(prefix+"-correct")
    main.show_round();main.finish_round(false,answer);await snap(prefix+"-wrong")
    main.show_results();await snap(prefix+"-results")
   elif id==8:
    main.flip_memory(0);await snap(prefix+"-first-card")
   else:
    # Capture hidden own card; do not expose it to simulate a successful guess.
    assert(main.active_play_screen)
   print("CORE_REFERENCE game=",id," language=",language," fixture_only=true")
 main.queue_free();await process_frame
 print("CORE_REFERENCE_CAPTURE_PASS=true captures=",captures)
 quit(0)
