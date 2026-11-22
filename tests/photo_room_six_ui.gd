extends SceneTree
var failures=[]
var clients=[]
var endpoint="ws://127.0.0.1:8900"
func _initialize(): call_deferred("run")
func check(ok: bool, name: String):
 print("PHOTO_SIX_UI ",name," ",ok)
 if not ok: failures.append(name)
func until(pred: Callable) -> bool:
 var end=Time.get_ticks_msec()+9000
 while Time.get_ticks_msec()<end:
  if pred.call(): return true
  await create_timer(.03).timeout
 return false
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--endpoint="):endpoint=arg.trim_prefix("--endpoint=")
 create_timer(90).timeout.connect(func():print("PHOTO_SIX_UI_TIMEOUT");quit(1))
 for i in range(6):
  var ui=load("res://scripts/photo_duel_extension_ui.gd").new()
  root.add_child(ui);ui.hide();ui.service_endpoint=endpoint
  ui.terms.button_pressed=true;clients.append(ui)
 var host=clients[0]
 host.players_field.select(4)
 host._request_room_action("create")
 if not await until(func():return not host.client.code.is_empty()):
  check(false,"create: "+host.status.text);quit(1);return
 check(true,"host creates six-player room")
 for i in range(1,6):
  clients[i].code_field.text=host.client.code
  clients[i]._request_room_action("join")
  if not await until(func():return clients[i].client.code==host.client.code):
   check(false,"join "+str(i)+": "+clients[i].status.text);quit(1);return
 check(await until(func():return clients.all(func(ui):return int(ui.client.state.get("joined",0))==6)),"all six see same lobby")
 for ui in clients:ui._accept_configuration()
 check(await until(func():return clients.all(func(ui):return bool(ui.client.state.get("started",false)))),"all six confirm and start")
 check(clients.all(func(ui):return int(ui.client.state.get("joined",0))==6),"all six retain membership")
 var question: String=str(host.client.state.preset_questions[0])
 host.presets[question].pressed.emit()
 check(await until(func():return clients[1].client.state.get("pending") is Dictionary),"preset question reaches designated responder")
 var image_id: String=str(clients[1].client.state.opponents.filter(func(item):return int(item.player)==0)[0].image)
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/guess_picture_302/catalog.json"))
 var correct_reply=false
 for item in data.items:
  if str(item.image)==image_id:correct_reply=bool(item.facts[question])
 if correct_reply:clients[1].yes_button.pressed.emit()
 else:clients[1].no_button.pressed.emit()
 check(await until(func():return int(host.client.state.current)==1),"responder answer advances turn")
 clients[1].guess_field.text="تخمين تجريبي"
 clients[1].guess_button.pressed.emit()
 check(await until(func():return host.client.state.get("pending") is Dictionary and host.client.state.pending.get("kind")=="guess"),"guess reaches designated responder")
 var responder: int=int(host.client.state.pending.responder)
 clients[responder].correct_button.pressed.emit()
 check(await until(func():return int(clients[1].client.state.scores[1])==1),"confirmation awards synchronized score")
 check(await until(func():return clients.all(func(ui):return int(ui.client.state.scores[1])==1)),"all six observe same score")
 var errors_before: int=host.client.error_count
 var revision_before: int=int(host.client.state.revision)
 host.client.send_action("duel_sync")
 check(await until(func():return int(host.client.state.revision)>revision_before),"sync works while waiting for next round")
 host.client.send_action("duel_chat",{"text":"test"})
 check(await until(func():return not host.client.state.get("chat",[]).is_empty()),"chat works while waiting for next round")
 host.client.send_action("duel_leave")
 check(await until(func():return clients.all(func(ui):return ui.client.code.is_empty())),"leaving closes waiting room for everyone")
 check(host.client.error_count==errors_before,"round break controls accepted")
 for ui in clients:ui.client.close_transport();ui.queue_free()
 await process_frame
 print("PHOTO_SIX_REAL_UI_WS ",failures.is_empty()," ",failures)
 quit(0 if failures.is_empty() else 1)
