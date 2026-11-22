extends SceneTree
const Fixture=preload("res://tests/open_heart_play_view.gd")
var failed:=false
func _initialize() -> void:call_deferred("run")
func ck(value: bool,message: String) -> void:
 if not value:failed=true;push_error(message)
func run() -> void:
 root.content_scale_size=Vector2i(420,840);root.size=Vector2i(420,840)
 root.get_node("PublishedContent").busy=true;root.get_node("GamingHubAccount").api_base=""
 var policy=root.get_node("RoomAudioPolicy");policy.set_music_enabled(false);policy.set_effects_enabled(false)
 var photo=load("res://scripts/photo_duel_extension_ui.gd").new();root.add_child(photo)
 photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 photo.client.code="123456";photo.client.player=0;photo.client.capabilities={"voice":true,"room_agreement":true}
 var state: Dictionary={"capacity":2,"joined":2,"connected":[true,true],"scores":[0,0],"profiles":[],"current":0,"responder":1,"room_agreement":true,"started":true,"primary_mode":"voice","remaining_ms":20000,"timer":30}
 photo.client.state=state;photo._state(state);await process_frame;await process_frame
 var mute: Vector2=photo.voice_mute_button.global_position
 ck(photo._room_shell.visible and photo._match_controls.is_visible_in_tree(),"photo shell shows existing controls")
 ck(photo._reply_row.get_parent()==photo._room_shell.reply_dock,"photo answer controls use fixed dock")
 var first_turn: StyleBoxFlat=photo._seat_panels[0].get_theme_stylebox("panel")
 var waiting: StyleBoxFlat=photo._seat_panels[1].get_theme_stylebox("panel")
 ck(first_turn.border_width_left==2 and waiting.border_width_left==1,"active turn is highlighted")
 state.current=1;photo.client.state=state;photo._state(state);await process_frame
 first_turn=photo._seat_panels[0].get_theme_stylebox("panel")
 waiting=photo._seat_panels[1].get_theme_stylebox("panel")
 ck(first_turn.border_width_left==1 and waiting.border_width_left==2,"highlight follows server turn")
 state.paused=true;photo.client.state=state;photo._state(state);await process_frame;await process_frame
 ck(photo.voice_mute_button.global_position.is_equal_approx(mute),"photo reconnect retains mute position")
 state.paused=false;state.match_finished=true;state.winner=-1;state.voice={"available":true};photo.client.state=state;photo._state(state);await process_frame;await process_frame
 ck(photo.status.text.contains("بالتعادل") and photo._room_shell.result.visible,"photo final draw is visible")
 ck(photo.status.text.contains("الصوت متاح"),"voice availability is shown only when supported")
 ck(not photo._room_shell.notice.visible,"final result does not repeat the status above the standings")
 ck(not photo._room_shell.result_trophy.visible,"draw does not display a winner trophy")
 ck(photo.voice_mute_button.global_position.is_equal_approx(mute),"photo results retain mute position")
 state.paused=true;photo.client.state=state;photo._state(state);await process_frame
 ck(photo._room_shell.notice.visible and not photo.status.text.contains("الصوت متاح"),"reconnect notice replaces voice availability while paused")
 state.paused=false
 state.primary_mode="tap";state.winner=1;state.scores=[0,10];state.profiles=[{}, {"display_name":"نورا"}];photo.client.state=state;photo._state(state);await process_frame
 ck(photo._room_shell.result_trophy.visible,"server-confirmed winner displays the trophy")
 ck(photo.status.text.contains("نورا") and not photo.status.text.contains("الصوت متاح"),"winner name and unavailable voice state are accurate")
 ck(photo._room_shell.result_standings.visible and photo._room_shell.result_standings.get_child(0).get_meta("player_index")==1,"photo standings use the server scores")
 photo.queue_free();await process_frame
 var ui=load("res://scripts/shared_quiz_ui.gd").new();root.add_child(ui);ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var transport=ui.client;ui.client=Fixture.RecordingClient.new();root.add_child(ui.client)
 ui.client.code="654321";ui.client.player=0;ui.client.capabilities={"shared_quiz":true,"room_agreement":true}
 ui.selected_game="1";ui._pending_room_action="create"
 ui._room_protocol_ready({"shared_quiz":true,"quiz_games":["6"],"room_agreement":true})
 ck(ui._pending_room_action.is_empty() and ui.client.sent.is_empty(),"unsupported game does not create a room")
 ui._pending_room_action="create";ui._room_protocol_ready({"shared_quiz":true,"quiz_games":["1"],"room_agreement":true})
 ck(ui.client.sent.size()==1 and ui.client.sent[0].type=="duel_quiz_create","advertised game can create a room")
 ui.client.sent.clear()
 ui.client.state={"primary_mode":"voice"};ui._propose_configuration()
 ck(ui.client.sent.size()==1 and ui.client.sent[0].fields.primary_mode=="voice","changing quiz category preserves the agreed voice mode")
 ui.client.sent.clear()
 var lobby: Dictionary={"capacity":2,"joined":1,"connected":[true,false],"scores":[0,0],"room_agreement":true,"primary_mode":"tap","started":false}
 ui.client.state=lobby;ui._state(lobby);await process_frame
 ck(ui.quiz_shell.visible and not ui.quiz_shell.reply_dock.visible,"quiz lobby hides empty answer controls")
 state={"capacity":2,"joined":2,"connected":[true,true],"scores":[0,0],"room_agreement":true,"primary_mode":"tap","started":true,"quiz":{"phase":"question","round":1,"rounds":2,"start_unix_ms":0,"question":{"id":"q1","mode":"choice","ar":"سؤال؟","en":"Question?","choices_ar":["أ","ب"],"choices_en":["A","B"]},"your_answer":null}}
 ui.client.state=state;ui._state(state);await process_frame
 ck(ui.quiz_shell.visible and ui.answer_buttons[0].is_visible_in_tree(),"quiz shell shows answer grid")
 ui.answer_buttons[0].pressed.emit();ui.answer_buttons[1].pressed.emit()
 await process_frame;await process_frame
 ck(ui.client.sent.size()==1,"quiz repeat tap sends one answer")
 ck(ui.answer_buttons[0].disabled and ui.answer_buttons[1].disabled,"quiz frame loop cannot unlock pending answer")
 ck(not ui.answer_buttons[0].text.begins_with("✓"),"correctness stays hidden before server reveal")
 state.quiz.your_answer=0;ui.client.state=state;ui._state(state)
 ck(ui.send_status.text.contains("تم تسجيل"),"canonical answer acknowledgement is visible")
 state.quiz.phase="results";state.quiz.correct_index=1;ui.client.state=state;ui._state(state)
 ck(ui.answer_buttons[1].text.begins_with("✓") and ui.answer_buttons[0].text.begins_with("✕"),"server reveal preserves correctness feedback")
 state.quiz.phase="finished";state.winner=1;state.scores=[0,10];ui.client.state=state;ui._state(state);await process_frame
 ck(not ui.answer_grid.visible and ui.quiz_final_title.visible,"finished match replaces answer controls with results")
 ck(ui.quiz_shell.more_button.get_index()>ui.quiz_panel.get_index(),"room options follow the match results")
 ck(ui.quiz_shell.result_trophy.visible and ui.quiz_final_title.text.contains("2"),"server winner is shown in the final match")
 ck(ui.quiz_scoreboard.get_child_count()==2 and ui.quiz_scoreboard.get_child(0).get_meta("player_index")==1,"final standings follow server totals")
 ck(ui.quiz_scoreboard.get_child(0).get_child(0).get_child(2).text=="10","standings show the actual total")
 state.profiles=[{"display_name":"أحمد"},{"display_name":"نورا"}];ui.client.state=state;ui._state(state);await process_frame
 ck(ui.quiz_final_title.text.contains("نورا"),"winner uses the server profile name")
 state.winner=-1;state.scores=[10,10];ui.client.state=state;ui._state(state);await process_frame
 ck(not ui.quiz_shell.result_trophy.visible and ui.quiz_final_title.text.contains("التعادل"),"draw is shown without a winner trophy")
 ck(ui.quiz_scoreboard.get_child(0).get_child(0).get_child(0).text=="1" and ui.quiz_scoreboard.get_child(1).get_child(0).get_child(0).text=="1","tied players share the same rank")
 state.quiz.phase="question";state.quiz.your_answer=null;ui.client.state=state;ui._state(state);await process_frame
 ck(ui.answer_grid.visible and ui.quiz_question_card.visible and not ui.quiz_scoreboard.visible,"new question restores answer controls")
 state.capacity=6;state.joined=6;state.connected=[true,true,true,true,true,true]
 state.scores=[10,20,30,40,50,60];state.profiles=[];state.winner=5;state.quiz.phase="finished"
 ui.client.state=state;ui._state(state);await process_frame;await process_frame
 ck(ui.quiz_scoreboard.get_child_count()==6 and ui.quiz_scoreboard.get_child(0).get_meta("player_index")==5,"six-player standings sort the actual scores")
 var last_row: Control=ui.quiz_scoreboard.get_child(5)
 ui.quiz_shell.scroll.ensure_control_visible(last_row);await process_frame;await process_frame
 ck(last_row.global_position.y+last_row.size.y<=ui.quiz_shell.scroll.global_position.y+ui.quiz_shell.scroll.size.y+1.0,"last standing remains reachable by scrolling")
 ui.client.queue_free();ui.client=transport;ui.queue_free();await process_frame
 print("ROOM_PLAY_SHELL_PASS="+str(not failed)+" photo/quiz fixed controls, duplicate lock, server reveal")
 quit(1 if failed else 0)
