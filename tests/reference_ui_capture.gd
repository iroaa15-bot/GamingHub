extends SceneTree
## Native rendering fixtures only; not screenshots of real multiplayer sessions.
var folder: String="user://reference_captures"
var captures:=0
func _initialize() -> void:call_deferred("run")
func snap(file_name: String) -> void:
 await process_frame;await process_frame
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var result:=root.get_texture().get_image().save_png(folder.path_join(file_name+".png"))
 assert(result==OK);captures+=1
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
 main.question_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
 main.load_catalog();main.age_group="18plus";main.sound_enabled=false;main.reduced_motion=true
 for language in ["ar","en"]:
  main.selected_language=language
  main.layout_direction=Control.LAYOUT_DIRECTION_RTL if language=="ar" else Control.LAYOUT_DIRECTION_LTR
  main.show_welcome();await snap("welcome-"+language)
  main.show_home();await snap("catalog-"+language)
  main.show_modes(0);await snap("mode-"+language)
  main.show_accessibility();await snap("settings-"+language)
  main.show_player_account();await snap("profile-"+language)
 main.queue_free();await process_frame
 for slug in ["open_heart","act_it","who_among_us","show_skill","truth_or_fiction","table_flip"]:
  var local=load("res://scripts/"+slug+"_offline.gd").new();root.add_child(local)
  local.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  local.names_input.text="إسلام, نورا";local._start()
  await snap("offline-"+slug)
  assert(local.find_children("*","Button",true,false).size()>0)
  if slug!="table_flip":assert(local.find_child("SocialPromptCard",true,false)!=null)
  local.queue_free();await process_frame
 var script=load("res://scripts/social_room_ui.gd");script.selected_social="who_among_us"
 for language in ["ar","en"]:
  var ui=script.new();ui.language=language;root.add_child(ui);ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  ui.client.code="123456";ui.client.player=0
  ui.client.capabilities={"voice":true,"room_agreement":true,"primary_modes":["voice","mixed","text","tap"]}
  for count in range(2,7):
   var state: Dictionary={"code":"123456","capacity":count,"joined":count,"connected":[],"scores":[],"confirmed":[],"profiles":[],"current":0,"started":false,"room_agreement":true,"primary_mode":"voice","party":{"category":"who_among_us","phase":"lobby","rounds":10}}
   for i in range(count):
    state.connected.append(i!=count-1);state.scores.append(10*i);state.confirmed.append(i!=count-1)
    state.profiles.append({"display_name":(["إسلام","نورا","عمر","حور","زين","رقية"] if language=="ar" else ["Islam","Nora","Omar","Hoor","Zain","Ruqaya"])[i]})
   ui.client.state=state;ui._state(state);await snap("lobby-%s-%d"%[language,count])
   assert(ui._seats.is_visible_in_tree())
   state.started=true;state.connected[count-1]=true
   state.party={"category":"who_among_us","phase":"active","round":0,"rounds":10,"actor":"0","card_id":"fixture","card":{"text_ar":"مين فينا أكتر شخص بيحب السفر؟","text_en":"Who among us loves travelling most?"},"voted_players":[]}
   ui.client.state=state;ui._state(state);await snap("question-%s-%d"%[language,count])
   assert(ui.party_panel.find_child("SocialPromptCard",true,false)!=null)
   state.party.phase="finished";state.party.round=10;state.match_finished=true;state.winner=count-1
   ui.client.state=state;ui._state(state);await snap("results-%s-%d"%[language,count])
  ui.queue_free();await process_frame
 for game_id in ["1","6"]:
  var quiz_script=load("res://scripts/shared_quiz_ui.gd");quiz_script.selected_game=game_id
  for language in ["ar","en"]:
   var view=quiz_script.new();view.language=language;root.add_child(view);view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
   view.client.code="123456";view.client.player=0;view.client.capabilities={"room_agreement":true}
   var question: Dictionary={"id":"reference-"+game_id,"mode":"choice","ar":"ما هذا الصوت؟" if game_id=="6" else "أي نوع من الأفلام يعتمد على الرسوم المتتابعة؟","en":"What is this sound?" if game_id=="6" else "Which type of film uses sequential drawings?","choices_ar":["جرس","رياح","قطار","مطر"] if game_id=="6" else ["رسوم متحركة","وثائقي","كوميديا","دراما"],"choices_en":["Bell","Wind","Train","Rain"] if game_id=="6" else ["Animation","Documentary","Comedy","Drama"]}
   if game_id=="6":question.audio="res://assets/audio/bell.wav"
   var value: Dictionary={"code":"123456","capacity":2,"joined":2,"connected":[true,true],"profiles":[{"display_name":"Islam"},{"display_name":"Nora"}],"scores":[0,0],"started":true,"room_agreement":true,"primary_mode":"tap","quiz":{"phase":"question","round":1,"rounds":10,"question":question,"your_answer":null,"replay_available":true}}
   view.client.state=value;view._state(value);await snap("quiz-%s-%s"%[game_id,language])
   assert(view.quiz_question_card.is_visible_in_tree())
   value.quiz.phase="results";value.quiz.correct_index=0;value.quiz.your_answer=1
   view.client.state=value;view._state(value);await snap("quiz-result-%s-%s"%[game_id,language])
   assert(view.answer_buttons[0].text.begins_with("✓ ") and view.answer_buttons[1].text.begins_with("✕ "))
   view.queue_free();await process_frame
 print("REFERENCE_NATIVE_RENDER captures=",captures," fixture_only=true AR/EN menus, profile/settings, lobby/question/results 2..6")
 quit(0)
