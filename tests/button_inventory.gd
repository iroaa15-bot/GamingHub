extends SceneTree
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func capture(view: Node,screen: String,language: String) -> void:
 for control in view.find_children("*","BaseButton",true,false):
  if not control.is_visible_in_tree():continue
  var handlers: Array=[]
  for event in ["pressed","toggled","gui_input"]:
   for connection in control.get_signal_connection_list(event):handlers.append(event+":"+str(connection.callable.get_method()))
  var behavior: String="callback" if not handlers.is_empty() else ("native selection" if control is OptionButton or control is MenuButton or control is CheckBox or control is CheckButton else "custom gesture" if control.get_script()!=null else "UNWIRED")
  rows.append({"screen":screen,"language":language,"text":control.text,"type":control.get_class(),"enabled":not control.disabled,"behavior":behavior,"handlers":handlers})
func run() -> void:
 create_timer(120).timeout.connect(func():push_error("Button inventory timeout");quit(1))
 root.get_node("PublishedContent").busy=true
 var policy=root.get_node("RoomAudioPolicy");policy.set_music_enabled(false);policy.set_effects_enabled(false)
 var main=load("res://tests/button_audit_main.gd").new();root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 await process_frame
 main.sound_enabled=false;main.ui_sound_enabled=false;main.music_enabled=false;main.reduced_motion=true
 main.age_group="18plus";main.audience="";main.session_length=10
 for language in ["ar","en"]:
  main.selected_language=language
  main.show_home();await process_frame;capture(main,"games",language)
  main.show_player_account();await process_frame;capture(main,"profile",language)
  main.show_player_friends();await process_frame;capture(main,"friends",language)
  main.show_accessibility();await process_frame;capture(main,"settings",language)
  for game in range(10):
   main.show_modes(game);await process_frame;capture(main,"mode_"+str(game),language)
   main._start_offline_mode();await process_frame;capture(main,"offline_"+str(game),language)
   if game not in [0,4,8] and not main.round_bank.is_empty():
    main.finish_round(false,main.correct_answer_text(main.round_bank[0]));await process_frame
    capture(main,"offline_feedback_"+str(game),language)
 var auth=root.get_node("GamingHubAccount")
 var previous_api: String=auth.api_base;auth.api_base=""
 var account=load("res://scenes/AccountScreen.tscn").instantiate();root.add_child(account)
 await process_frame;capture(account,"account_sign_in",account.language)
 account.queue_free();await process_frame;auth.api_base=previous_api
 var room=load("res://scripts/photo_duel_extension_ui.gd").new();root.add_child(room)
 await process_frame
 room._focus_room_entry("create");capture(room,"room_create",room.language)
 room._focus_room_entry("join");capture(room,"room_join",room.language)
 room.client.code="123456";room.client.player=0
 room.client.capabilities={"room_agreement":true,"voice":true,"primary_modes":["voice","text","mixed","tap"]}
 var state: Dictionary={"capacity":2,"joined":2,"connected":[true,true],"started":false,"current":0,"host":0,"responder":1,"scores":[0,0],"primary_mode":"tap","opponents":[],"room_agreement":true,"config_revision":1,"confirmed":[false,false]}
 room._state(state);capture(room,"room_preparation",room.language)
 state.started=true
 for mode in ["voice","text","mixed","tap"]:
  state.primary_mode=mode;state.config_revision+=1;state.pending={};room.client.player=0
  room._state(state);capture(room,"photo_turn_"+mode,room.language)
  assert(not room._settings_toggle.visible)
  assert(room._voice_controls.visible==(mode in ["voice","mixed"]))
  state.pending={"kind":"question","mode":mode,"text":"Fixture question","responder":1};room.client.player=1
  room._state(state);capture(room,"photo_reply_"+mode,room.language)
  assert(room.yes_button.visible and not room.guess_button.visible)
 state.pending={"kind":"guess","text":"Fixture guess","responder":1};room._state(state)
 capture(room,"photo_final_confirmation",room.language)
 assert(room.correct_button.visible and not room.yes_button.visible)
 room.queue_free();await process_frame
 var quiz=load("res://scripts/shared_quiz_ui.gd").new();root.add_child(quiz)
 await process_frame
 quiz.client.code="123456";quiz.client.player=0
 quiz.client.capabilities={"room_agreement":true,"shared_quiz":true,"voice":true,"primary_modes":["tap"]}
 state.pending={};state.primary_mode="tap";state.started=true
 for mechanic in ["choice","order","write","identity","memory"]:
  var question: Dictionary={"id":"fixture_"+mechanic,"mode":mechanic,"en":"Fixture question","ar":"سؤال اختبار","choices_en":["A","B","C","D"],"choices_ar":["أ","ب","ج","د"],"steps_en":["First","Second","Third"],"steps_ar":["الأول","الثاني","الثالث"],"size":4}
  state.quiz={"phase":"question","question":question,"round":1,"rounds":1,"start_unix_ms":0,"your_answer":null}
  quiz._state(state);await process_frame;capture(quiz,"shared_"+mechanic,quiz.language)
  assert(not quiz.yes_button.is_visible_in_tree() and not quiz._voice_question.is_visible_in_tree() and not quiz._settings_toggle.is_visible_in_tree())
  assert(quiz.answer_buttons.filter(func(control):return control.is_visible_in_tree()).size()==(4 if mechanic=="choice" else 0))
  assert(quiz.order_submit.is_visible_in_tree()==(mechanic=="order"))
  assert(quiz.written_submit.is_visible_in_tree()==(mechanic in ["write","identity"]))
 quiz.queue_free();await process_frame
 var output: String="user://button_inventory.json"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--audit-output="):output=argument.trim_prefix("--audit-output=")
 var file:=FileAccess.open(output,FileAccess.WRITE);assert(file!=null)
 file.store_string(JSON.stringify({"scope":"runtime visibility and handler wiring; not a physical click or external service acceptance","buttons":rows},"  "));file.close()
 var unwired: Array=rows.filter(func(row):return row.enabled and row.behavior=="UNWIRED")
 print("BUTTON_INVENTORY rows=",rows.size()," enabled_unwired=",unwired.size())
 for row in unwired:print("UNWIRED ",row.screen," ",row.text)
 assert(unwired.is_empty())
 main.queue_free();await process_frame
 quit(0)
