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
   if id==1:
    var expected_topics: Array=["all"]
    for item in main.eligible_questions(id,false):
     var topic: String=str(item.get("topic",""))
     if not topic.is_empty() and topic not in expected_topics:expected_topics.append(topic)
    var found_topics: Array=[]
    var all_card: Button=null
    for choice in main.root.find_children("*","Button",true,false):
     if not choice.has_meta("topic_value"):continue
     var key: String=str(choice.get_meta("topic_value"))
     found_topics.append(key);choice.button_pressed=true;choice.pressed.emit()
     assert(main.selected_topic==key)
     if key!="all":
      for question in main.eligible_questions(id,true):assert(str(question.get("topic",""))==key)
     else:all_card=choice
    assert(found_topics==expected_topics and all_card!=null)
    all_card.button_pressed=true;all_card.pressed.emit()
   var start: Button=null
   for node in main.root.find_children("*","Button",true,false):
    if node.get_meta("setup_action","")=="start":start=node
   assert(start!=null)
   start.grab_focus();start.pressed.emit();await process_frame;await process_frame;await process_frame
   assert(main.active_play_screen and main.has_node("CorePlayDock"))
   assert(main.root.get_parent().get_parent().scroll_vertical==0)
   main.pause_local_play();assert(is_instance_valid(main._local_pause_dialog) and main.blitz_dialog_paused)
   main._resume_local_play();assert(not main.blitz_dialog_paused)
   print("CORE_REDESIGN_ROUTE_PASS ",id," ",language)
 # Large-text mode must retain readable card type sizes when selection changes.
 main.game=1;main.selected_language="ar";main.reading_scale=1.5;main.show_offline_setup()
 await process_frame;await process_frame
 var large_topics: Array=[]
 for choice in main.root.find_children("*","Button",true,false):
  if choice.has_meta("topic_value"):large_topics.append(choice)
 assert(large_topics.size()>1)
 for choice in large_topics:
  choice.button_pressed=true;choice.pressed.emit()
  for card in large_topics:
   assert(card.get_theme_font_size("font_size")>=24 and card.size.y>=100)
 main.reading_scale=1.0;main.selected_topic="all"
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
