extends SceneTree
const Client = preload("res://scripts/photo_duel_extension_client.gd")
var failures := 0
var count := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, value: String) -> void:
 count += 1
 print(("PASS " if ok else "FAIL ")+value)
 if not ok: failures += 1
func until(predicate: Callable, seconds: float = 5.0) -> bool:
 var end := Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:
  if predicate.call(): return true
  await create_timer(.025).timeout
 return false
func run() -> void:
 if "--duel-case=negative" in OS.get_cmdline_user_args():
  await negative_only()
  return
 create_timer(60).timeout.connect(func(): print("FAIL lifecycle watchdog"); quit(2))
 if not Engine.is_editor_hint() or root.has_node("DailyRounds") or root.has_node("LiveOps"):
  print("FAIL unsafe test autoload configuration")
  quit(1)
  return
 var scene: PackedScene = load("res://scenes/PhotoDuelLocal.tscn")
 var scene_state := scene.get_state()
 var wired := false
 for index in range(scene_state.get_node_property_count(0)):
  if scene_state.get_node_property_name(0,index)=="script":
   wired = scene_state.get_node_property_value(0,index).resource_path=="res://scripts/photo_duel_extension_ui.gd"
 check(wired,"embedded scene is wired to tested UI script")
 # Editor-safe explicit script instances execute real UI code, avoiding editor placeholders.
 var ui: Variant = load("res://scripts/photo_duel_extension_ui.gd").new()
 root.add_child(ui)
 await process_frame
 var host: Node = ui.client
 await until(func(): return not host.capabilities.is_empty())
 ui.players_field.select(0)
 ui.timer_field.select(0)
 ui.target_field.value = 1
 ui.create_button.pressed.emit()
 check(await until(func(): return not host.code.is_empty()),"UI room creation for lifecycle scenario")
 var old_code: String = host.code
 var peer := Client.new()
 root.add_child(peer)
 peer.connect_endpoint(Client.endpoint_from_args())
 await until(func(): return not peer.capabilities.is_empty())
 peer.join_room(old_code)
 check(await until(func(): return bool(host.state.get("started",false))),"lifecycle room ready")
 ui.question_field.text="draft question preserved"
 ui.chat_field.text="draft chat preserved"
 peer.send_action("duel_chat",{"text":"incoming message"})
 await until(func(): return host.state.get("chat",[]).size()==1)
 check(ui.question_field.text=="draft question preserved" and ui.chat_field.text=="draft chat preserved","incoming state updates preserve editing fields and avoid rebuilding touch UI")
 ui.guess_field.text="pending reconnect guess"
 ui.guess_button.pressed.emit()
 check(await until(func(): return host.state.get("pending") is Dictionary),"UI guess action waits for confirmation")
 peer.close_transport()
 check(await until(func(): return bool(host.state.get("paused",false))),"disconnect during pending guess pauses room")
 var errors: int = host.error_count
 host.send_action("duel_pass")
 check(await until(func(): return host.error_count>errors),"gameplay rejected while room is paused")
 peer.resume_session()
 check(await until(func(): return not bool(host.state.get("paused",true))),"pending guess session reconnects")
 check(host.state.pending.text=="pending reconnect guess","pending guess and designated roles survive reconnect")
 peer.send_action("duel_confirm",{"correct":false})
 check(await until(func(): return host.state.pending==null and int(host.state.current)==1),"negative opponent confirmation advances turn")
 check(int(host.state.scores[0])==0 and int(host.state.scores[1])==0,"negative confirmation awards no score")
 peer.send_action("duel_guess",{"guess":"winning confirmation"})
 await until(func(): return host.state.get("pending") is Dictionary)
 ui.correct_button.pressed.emit()
 check(await until(func(): return bool(host.state.get("closed",false))),"UI opponent confirmation completes target score match")
 check(int(host.state.winner)==1 and int(host.state.scores[1])==1,"server confirms correct winner")
 check(host.token.is_empty() and peer.token.is_empty(),"closed room discards client resume credentials")
 ui.create_button.pressed.emit()
 check(await until(func(): return not host.code.is_empty() and host.code!=old_code),"same real UI connection can create next room immediately after win")
 host.send_action("duel_leave")
 await until(func(): return bool(host.state.get("closed",false)))
 # Regression for a stale child-client reference discovered during the first six-player teardown.
 host.close_transport()
 host.queue_free()
 await process_frame
 await process_frame
 check(is_instance_valid(ui),"UI survives client teardown without freed-node process access")
 ui.set_process(false)
 ui.queue_free()
 peer.close_transport()
 peer.queue_free()
 await process_frame
 await process_frame
 await create_timer(.1).timeout
 print("LIFECYCLE_CHECKS ",count," FAILURES ",failures)
 print("LOCAL_EXTENSION_"+("PASS" if failures==0 else "FAIL"))
 print("ANDROID_AUDIO_BLOCKED; ANDROID_TOUCH_BLOCKED; NO_APK_BUILT")
 quit(0 if failures==0 else 1)

func negative_only() -> void:
 create_timer(30).timeout.connect(func(): print("FAIL negative confirmation watchdog"); quit(2))
 if not Engine.is_editor_hint() or root.has_node("DailyRounds") or root.has_node("LiveOps"):
  quit(1)
  return
 var a := Client.new()
 var b := Client.new()
 root.add_child(a)
 root.add_child(b)
 a.connect_endpoint(Client.endpoint_from_args())
 b.connect_endpoint(Client.endpoint_from_args())
 await until(func(): return not a.capabilities.is_empty() and not b.capabilities.is_empty())
 a.create_room(2,0,1)
 await until(func(): return not a.code.is_empty())
 b.join_room(a.code)
 await until(func(): return bool(a.state.get("started",false)))
 a.send_action("duel_guess",{"guess":"negative confirmation regression"})
 await until(func(): return a.state.get("pending") is Dictionary)
 b.send_action("duel_confirm",{"correct":false})
 check(await until(func(): return a.state.pending==null and int(a.state.current)==1),"negative confirmation changes turn")
 print("Observed score values: ",a.state.scores," JSON element types: ",typeof(a.state.scores[0]),",",typeof(a.state.scores[1]))
 check(int(a.state.scores[0])==0 and int(a.state.scores[1])==0,"negative confirmation awards no score (numeric JSON comparison)")
 a.send_action("duel_leave")
 await until(func(): return bool(a.state.get("closed",false)))
 a.close_transport()
 b.close_transport()
 a.queue_free()
 b.queue_free()
 await process_frame
 await process_frame
 print("LOCAL_EXTENSION_"+("PASS" if failures==0 else "FAIL"))
 quit(0 if failures==0 else 1)
