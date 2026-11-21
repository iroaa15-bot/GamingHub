extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.content_scale_size=Vector2i(420,900)
 root.get_node("PublishedContent").busy=true;root.get_node("GamingHubAccount").api_base=""
 var policy=root.get_node("RoomAudioPolicy");policy.set_music_enabled(false);policy.set_effects_enabled(false)
 var main=load("res://tests/picture_ui_preview.gd").new();root.add_child(main)
 main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.ui_tr=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"))
 main.question_bank=load("res://scripts/approved_content.gd").questions(JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json")))
 main.load_catalog();main.age_group="18plus";main.audience="youth";main.sound_enabled=false;main.reduced_motion=true
 for language in ["ar","en"]:
  main.selected_language=language
  for id in range(10):
   main.show_modes(id);main._start_offline_mode()
   assert(main.current_screen=="offline_setup")
   if id==0:
    var difficulty_buttons:=0
    for choice in main.root.find_children("*","Button",true,false):
     if choice.has_meta("difficulty_value"):
      choice.pressed.emit()
      assert(main.difficulty==choice.get_meta("difficulty_value"))
      difficulty_buttons+=1
    assert(difficulty_buttons==3)
   var start: Button=null
   for node in main.root.find_children("*","Button",true,false):
    if node.get_meta("setup_action","")=="start":start=node
   assert(start!=null)
   start.pressed.emit();await process_frame;await process_frame;await process_frame
   assert(main.active_play_screen and main.has_node("CorePlayDock"))
   main.pause_local_play();assert(is_instance_valid(main._local_pause_dialog) and main.blitz_dialog_paused)
   main._resume_local_play();assert(not main.blitz_dialog_paused)
   print("CORE_REDESIGN_ROUTE_PASS ",id," ",language)
 # Existing timed mode really stops, then resumes, without awarding anything.
 main.game=5;main.match_style="blitz";main.start_game();await process_frame
 var score: int=main.score;main.pause_local_play()
 var left: float=main.blitz_timer.time_left
 await create_timer(.12).timeout
 assert(is_equal_approx(main.blitz_timer.time_left,left) and main.score==score)
 main._resume_local_play();await create_timer(.12).timeout
 assert(main.blitz_timer.time_left<left)
 main.queue_free();await process_frame
 print("CORE_REDESIGN_FLOW_PASS=true 10 games AR/EN setup, fixed actions, real pause/resume")
 quit(0)
