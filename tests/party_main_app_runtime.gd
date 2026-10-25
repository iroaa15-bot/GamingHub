extends SceneTree
var failures: Array[String] = []
func find_button(node: Node, text: String) -> Button:
 if node is Button and text in node.text:
  return node
 for child in node.get_children():
  var result := find_button(child,text)
  if result != null:
   return result
 return null
func wait_for(predicate: Callable, message: String) -> bool:
 var deadline := Time.get_ticks_msec()+9000
 while not predicate.call() and Time.get_ticks_msec()<deadline:
  await process_frame
 var passed: bool = predicate.call()
 if not passed:
  failures.append(message)
 return passed
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var main = load("res://scenes/Main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 await process_frame
 main.selected_language="ar"
 main.show_games_list_v2()
 var entry := find_button(main,"حفلات الأصدقاء")
 if entry == null:
  failures.append("Main app Party Room entry missing")
  finish()
  return
 entry.pressed.emit()
 await process_frame
 await process_frame
 var host = current_scene
 if host.scene_file_path != "res://scenes/PartyRoomStaging.tscn":
  failures.append("Main app navigation failed")
  finish()
  return
 var peer = load("res://scenes/PartyRoomStaging.tscn").instantiate()
 root.add_child(peer)
 await process_frame
 var endpoint := OS.get_environment("GAMINGHUB_PARTY_TEST_WS")
 host.address.text=endpoint
 host.player_name.text="App Host"
 find_button(host,"إنشاء غرفة").pressed.emit()
 if not await wait_for(func(): return not host.code.is_empty(),"app create room"):
  finish();return
 peer.address.text=endpoint
 peer.player_name.text="App Peer"
 peer.join_code.text=host.code
 find_button(peer,"الانضمام بكود").pressed.emit()
 if not await wait_for(func(): return peer.room_state.get("members",[]).size()==2,"app join room"):
  finish();return
 find_button(host,"أنا مستعد").pressed.emit()
 find_button(peer,"أنا مستعد").pressed.emit()
 await wait_for(func(): return host.room_state.get("members",[]).all(func(m):return m.ready),"app readiness")
 find_button(host,"بدء المباراة").pressed.emit()
 if not await wait_for(func(): return host.room_state.get("phase")=="active" and peer.room_state.get("phase")=="active","app start"):
  finish();return
 host.answer.text="banana"
 find_button(host,"إرسال الإجابة").pressed.emit()
 await wait_for(func():return peer.room_state.get("bomb_player")==peer.player_id,"app turn synchronization")
 peer.answer.text="bear"
 find_button(peer,"إرسال الإجابة").pressed.emit()
 await wait_for(func():return host.room_state.get("submitted_count")==2,"app answers")
 find_button(host,"كشف الإجابات").pressed.emit()
 await wait_for(func():return peer.room_state.get("phase")=="reveal","app reveal")
 if int(peer.room_state.get("scores",{}).get(peer.player_id,0))!=1:
  failures.append("app scoreboard")
 host._send({"type":"party.chat","text":"app chat verified"})
 await wait_for(func():return not peer.chat_history.is_empty(),"app chat")
 var old_token: String=peer.resume_token
 peer.socket.close()
 await wait_for(func():return not peer.connected,"app disconnect")
 peer._lobby()
 peer.address.text=endpoint
 find_button(peer,"استعادة الجلسة").pressed.emit()
 await wait_for(func():return peer.resume_token!=old_token and peer.connected,"app resume")
 peer.queue_free()
 host.socket.close()
 await process_frame
 finish()
func finish() -> void:
 for failure in failures:
  push_error(failure)
 print("PARTY_MAIN_APP_RUNTIME failures=",failures.size()," main-menu navigation, create/join, game turn, scoreboard, chat, reconnect")
 quit(0 if failures.is_empty() else 1)
