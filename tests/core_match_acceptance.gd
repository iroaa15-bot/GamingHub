extends SceneTree
## White-box local match acceptance with real answer validators; no profile disk writes.
func _initialize() -> void:call_deferred("run")
func answer(main: Control, correct: bool) -> void:
 var item: Dictionary=main.round_bank[main.question_index]
 match str(item.get("mode","choice")):
  "write","identity":main.submit_written(str(item["answers_"+main.selected_language][0]) if correct else "__wrong__")
  "order":
   main.order_picks.clear()
   for i in range(item["steps_"+main.selected_language].size()):main.order_picks.append(i)
   if not correct:main.order_picks.reverse()
   main.submit_order()
  _:main.select_answer(int(item.correct) if correct else (int(item.correct)+1)%4)
func run() -> void:
 root.get_node("PublishedContent").busy=true;root.get_node("GamingHubAccount").api_base=""
 var policy=root.get_node("RoomAudioPolicy");policy.set_music_enabled(false);policy.set_effects_enabled(false)
 var main=load("res://tests/picture_ui_preview.gd").new();root.add_child(main)
 main.ui_tr=JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"))
 main.question_bank=load("res://scripts/approved_content.gd").questions(JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json")))
 main.load_catalog();main.age_group="18plus";main.audience="youth"
 main.sound_enabled=false;main.reduced_motion=true;main.session_length=5
 for language in ["ar","en"]:
  main.selected_language=language
  for id in range(10):
   main.game=id;main.match_style="classic";main.selected_topic="all"
   main.start_game()
   if id==0:
    for stage in range(main.picture_stage_count):
     assert(not main.picture_done)
     main.submit_picture_guess(str(main.my_secret.name))
     assert(main.picture_done)
     var xp: int=int(main.profile.xp)
     main.submit_picture_guess(str(main.my_secret.name));assert(int(main.profile.xp)==xp)
     main.next_picture_stage()
    assert(main.picture_stage==main.picture_stage_count and main.picture_done)
   elif id==8:
    for stage in range(main.memory_stage_count):
     var pairs: Dictionary={}
     for i in range(main.memory_cards.size()):
      var key: String=main.memory_cards[i]
      if not pairs.has(key):pairs[key]=[]
      pairs[key].append(i)
     for pair in pairs.values():main.flip_memory(pair[0]);main.flip_memory(pair[1])
     assert(main.memory_done)
     var xp: int=int(main.profile.xp)
     main.finish_memory();assert(int(main.profile.xp)==xp)
     main.next_memory_board()
    assert(main.memory_stage==main.memory_stage_count and main.memory_done)
   else:
    assert(not main.round_bank.is_empty())
    var count: int=main.round_bank.size()
    for i in range(count):
     assert(main.question_index==i)
     answer(main,i%2==0)
     assert(main.round_finished)
     var score: int=main.score
     answer(main,true);assert(main.score==score)
     main.next_round()
     if main.question_index<count:main.show_round()
    # Standard milestone UI defers the final result commit until Continue.
    main.finish_match()
    assert(main.match_reward_committed)
    var xp: int=int(main.profile.xp)
    main.finish_match();assert(int(main.profile.xp)==xp)
   print("CORE_MATCH_PASS game=",id," language=",language," local=true")
 main.queue_free();await process_frame
 print("CORE_MATCH_ACCEPTANCE_PASS=true games=10 languages=2 validators_and_reward_idempotency=true")
 quit(0)
