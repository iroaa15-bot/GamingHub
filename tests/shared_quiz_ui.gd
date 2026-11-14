extends SceneTree
var folder="user://quiz_captures"
var failures=[]
var game_id="1"
func _initialize() -> void:call_deferred("run")
func until(predicate: Callable) -> bool:
 var end=Time.get_ticks_msec()+6000
 while Time.get_ticks_msec()<end:
  if predicate.call():return true
  await create_timer(.025).timeout
 return false
func ck(ok: bool,name: String) -> void:
 print("QUIZ_UI_CHECK ",name," ",ok)
 if not ok:failures.append(name)
func snap(name: String) -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run() -> void:
 create_timer(30).timeout.connect(func():print("QUIZ_UI_TIMEOUT");quit(1))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
  if arg.begins_with("--quiz="):game_id=arg.trim_prefix("--quiz=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder));root.content_scale_size=Vector2i(420,900)
 var script=load("res://scripts/shared_quiz_ui.gd");script.selected_game=game_id
 var a=script.new();root.add_child(a);a.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var b=script.new();root.add_child(b);b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);b.hide()
 a.service_endpoint="ws://127.0.0.1:8884";a.terms.button_pressed=true;a.target_field.value=1;a._request_room_action("create")
 ck(await until(func():return not a.client.code.is_empty()),"shared UI create via authenticated transport")
 b.service_endpoint="ws://127.0.0.1:8884";b.terms.button_pressed=true;b.code_field.text=a.client.code;b._request_room_action("join")
 ck(await until(func():return a.client.state.get("joined",0)==2 and b.client.state.get("joined",0)==2),"UI code join")
 a._accept_configuration();b._accept_configuration()
 await until(func():return a.client.state.confirmed.count(true)==2)
 a.client.send_action("duel_start")
 ck(await until(func():return a.quiz_panel.visible and b.quiz_panel.visible),"quiz controls actually rendered")
 ck(a.answer_buttons[0].text==b.answer_buttons[0].text and not a._match_controls.visible,"same choices with duel controls hidden")
 await create_timer(1.6).timeout
 if game_id=="6":ck(a.audio_player.stream!=null and a.audio_player.playing,"scheduled original audio actually playing in Godot")
 await snap(("sound" if game_id=="6" else "cinema")+"-shared-question")
 a.answer_buttons[0].pressed.emit();b.answer_buttons[1].pressed.emit()
 ck(await until(func():return a.client.state.quiz.phase=="finished"),"actual answer callbacks reach shared results")
 await snap(("sound" if game_id=="6" else "cinema")+"-shared-results")
 a.client.send_action("duel_leave")
 for ui in [a,b]:ui.client.close_transport();ui.queue_free()
 await process_frame
 print("SHARED_QUIZ_UI_REAL_WS ",failures.is_empty()," ",failures)
 quit(0 if failures.is_empty() else 1)
