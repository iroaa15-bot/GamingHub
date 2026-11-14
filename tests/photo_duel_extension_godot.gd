extends SceneTree
const Client = preload("res://scripts/photo_duel_extension_client.gd")
var failures: Array[String] = []
var endpoint := ""
var catalog: Dictionary = {}
var checks := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> bool:
 checks += 1
 print(("PASS " if ok else "FAIL ")+message)
 if not ok: failures.append(message)
 return ok
func until(predicate: Callable, seconds: float = 5.0) -> bool:
 var end := Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:
  if predicate.call(): return true
  await create_timer(0.025).timeout
 return false
func node_client() -> Node:
 var node := Client.new()
 root.add_child(node)
 node.connect_endpoint(endpoint)
 return node
func ready_client(node: Node) -> bool:
 return await until(func(): return not node.capabilities.is_empty())
func cleanup(clients: Array) -> void:
 for node in clients:
  if is_instance_valid(node):
   node.close_transport()
   node.queue_free()
 await process_frame
func pending_is(node: Node, kind: String) -> bool:
 return node.state.get("pending") is Dictionary and node.state.pending.get("kind")==kind
func active_image(clients: Array, player: int) -> String:
 for other in clients:
  if other.player != player:
   for image in other.state.get("opponents",[]):
    if int(image.player)==player: return str(image.image)
 return ""
func run() -> void:
 create_timer(120).timeout.connect(func(): print("FAIL test watchdog"); quit(2))
 # --editor prevents runtime autoloads from contacting daily-content production endpoints.
 if not check(Engine.is_editor_hint() and not root.has_node("DailyRounds") and not root.has_node("LiveOps"),"local-only harness: runtime production autoloads not instantiated"):
  quit(1)
  return
 endpoint = Client.endpoint_from_args()
 if not check(not endpoint.is_empty(),"explicit local endpoint accepted"):
  quit(1)
  return
 check(not Client.allowed_endpoint("wss://gaminghub-multiplayer.onrender.com"),"client refuses production endpoint")
 check(not Client.allowed_endpoint("ws://8.8.8.8:8771"),"client refuses public endpoint")
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guess_picture_302/catalog.json"))
 for item in data.items:
  if item.group == "original_200": catalog[str(item.image)] = item
 var timers := [0,10,20,30,60]
 var sizes: Array = [2,3,4,5,6]
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--duel-sizes="):
   sizes = []
   for part in arg.trim_prefix("--duel-sizes=").split(","): sizes.append(int(part))
 for size in sizes:
  var clients: Array = []
  var ui: Variant = null
  var host: Node
  if size == 6:
   ui = load("res://scripts/photo_duel_extension_ui.gd").new()
   root.add_child(ui)
   await process_frame
   host = ui.client
   ui.players_field.select(size-2)
   ui.timer_field.select(size-2)
   ui.target_field.value = 2
  else: host = node_client()
  clients.append(host)
  if not check(await ready_client(host),"v3 capability negotiation for "+str(size)+" players"):
   await cleanup(clients)
   continue
  if ui != null: ui.create_button.pressed.emit()
  else: host.create_room(size,timers[size-2],2)
  if not check(await until(func(): return not host.code.is_empty()),"create "+str(size)+" player room"):
   await cleanup(clients)
   continue
  var room_code: String = host.code
  for i in range(1,size):
   var peer := node_client()
   clients.append(peer)
   await ready_client(peer)
   peer.join_room(room_code)
   await until(func(): return peer.player == i)
  var joined: bool = await until(func(): return bool(host.state.get("started",false)) and int(host.state.get("joined",0))==size)
  check(joined,"all "+str(size)+" real WebSocket Godot clients joined")
  if not joined:
   await cleanup(clients)
   continue
  await until(func(): return bool(clients[-1].state.get("started",false)))
  check(int(host.state.timer)==int(timers[size-2]),"configured timer "+str(timers[size-2])+" accepted by server")
  if timers[size-2]==0:
   check(host.state.deadline_unix_ms == null and host.state.remaining_ms == null,"timer 0 has no authoritative deadline")
  else:
   check(int(host.state.remaining_ms)>int(timers[size-2])*1000-5000,"server supplies actual configured deadline")
  var visibility := true
  for peer in clients:
   if peer.state.get("opponents",[]).size() != size-1: visibility=false
   for image in peer.state.get("opponents",[]):
    if int(image.player)==peer.player or not catalog.has(str(image.image)): visibility=false
  check(visibility,"per-player state hides own picture and uses only original assets for "+str(size))
  var message := "مرحبا • hello • merhaba "+str(size)
  if ui != null:
   ui.chat_field.text = message
   ui.chat_button.pressed.emit()
  else: host.send_action("duel_chat",{"text":message})
  var delivered := true
  for peer in clients:
   if not await until(func(): return peer.state.get("chat",[]).size()>0 and peer.state.chat[-1].text==message): delivered=false
  check(delivered,"free Unicode chat reaches every real client in "+str(size)+" player room")
  var asker: int = int(host.state.current)
  clients[asker].send_action("duel_question",{"text":"هل يوجد في المنزل؟ / At home?"})
  check(await until(func(): return pending_is(host,"question")),"free text question becomes authoritative pending action")
  var responder: int = int(host.state.pending.responder)
  var old_errors: int = clients[asker].error_count
  clients[asker].send_action("duel_reply",{"answer":true,"player":responder})
  check(await until(func(): return clients[asker].error_count>old_errors),"spoofed/self yes-no reply rejected")
  clients[responder].send_action("duel_reply",{"answer":false})
  check(await until(func(): return int(host.state.current)==responder and host.state.pending==null),"designated opponent No reply transfers turn")
  check(host.state.history.any(func(event): return event.get("kind")=="reply" and event.get("answer")==false),"No answer retained for reconnect")
  asker = responder
  var image_path := active_image(clients,asker)
  var fact: bool = bool(catalog[image_path].facts.living)
  clients[asker].send_action("duel_preset",{"question_id":"living"})
  check(await until(func(): return pending_is(host,"question")),"preset question pending on actual server")
  responder = (asker+1)%size
  old_errors = clients[responder].error_count
  clients[responder].send_action("duel_reply",{"answer":not fact})
  check(await until(func(): return clients[responder].error_count>old_errors),"preset yes-no reply contradicting photo rejected")
  clients[responder].send_action("duel_reply",{"answer":fact})
  check(await until(func(): return int(host.state.current)==responder and host.state.pending==null),"correct preset yes/no reply accepted")
  asker = responder
  clients[asker].send_action("duel_guess",{"guess":"التخمين / guess"})
  check(await until(func(): return pending_is(host,"guess")),"guess waits for opponent confirmation")
  responder=(asker+1)%size
  old_errors=clients[asker].error_count
  clients[asker].send_action("duel_confirm",{"correct":true,"player":responder})
  check(await until(func(): return clients[asker].error_count>old_errors),"self/forged guess confirmation rejected")
  clients[responder].send_action("duel_confirm",{"correct":true})
  check(await until(func(): return int(host.state.scores[asker])==1 and host.state.pending==null),"opponent confirmation alone awards score")
  check(int(host.state.round)==2,"new round starts after confirmed guess")
  # Explicit disconnection of a real socket, never a mock peer.
  var dropped: Node = clients[-1]
  var old_token: String = dropped.token
  var current: int = int(host.state.current)
  dropped.close_transport()
  var observer: Node = clients[0]
  check(await until(func(): return bool(observer.state.get("paused",false))),"disconnect pauses "+str(size)+" player room")
  var paused_left: Variant = observer.state.get("remaining_ms")
  await create_timer(.2).timeout
  dropped.resume_session()
  check(await until(func(): return not dropped.capabilities.is_empty() and dropped.token != old_token and not bool(observer.state.get("paused",true))),"real reconnect rotates token and resumes room")
  check(int(observer.state.current)==current,"reconnect preserves turn")
  check(not dropped.state.get("chat",[]).is_empty(),"reconnect restores free chat history")
  if paused_left != null: check(int(observer.state.remaining_ms)<=int(paused_left)+100,"reconnect preserves remaining timer without reset")
  var outsider := node_client()
  await ready_client(outsider)
  old_errors=outsider.error_count
  outsider.send_action("duel_resume",{"code":room_code,"token":old_token})
  check(await until(func(): return outsider.error_count>old_errors),"old resume token cannot hijack room")
  clients.append(outsider)
  if size == 3:
   current=int(host.state.current)
   check(await until(func(): return int(host.state.current)!=current,12),"actual 10 second server timer expires and advances turn")
   check(host.state.history.any(func(event): return event.get("reason")=="timeout"),"authoritative timeout event reaches Godot client")
  if ui != null:
   check(ui.client==host and ui.images[host.player].visible==false,"embedded Gaming Hub UI uses v3 client and hides own image")
   check(ui.chat_field.text.is_empty(),"real UI chat action cleared field after send")
  host.send_action("duel_leave")
  await until(func(): return bool(host.state.get("closed",false)))
  await cleanup(clients)
  if ui != null: ui.queue_free(); await process_frame
 if "--duel-case=six" in OS.get_cmdline_user_args():
  print("ANDROID_AUDIO_BLOCKED; ANDROID_TOUCH_BLOCKED; NO_APK_BUILT")
  print("EXTENSION_CHECKS ",checks," FAILURES ",failures.size())
  print("LOCAL_EXTENSION_"+("PASS" if failures.is_empty() else "FAIL"))
  quit(0 if failures.is_empty() else 1)
  return
 # Only new extension validation; not the previously passed production feature suite.
 var invalid := node_client()
 await ready_client(invalid)
 for setting in [{"players":7,"timer":0},{"players":2,"timer":15},{"players":2,"timer":true}]:
  var before: int = invalid.error_count
  invalid.send_action("duel_create",setting)
  check(await until(func(): return invalid.error_count>before),"invalid extension setting rejected: "+str(setting))
 invalid.close_transport()
 invalid.queue_free()
 # New compatibility boundary: original client talking to the separate endpoint, never production.
 var legacy_a: Variant = load("res://scripts/multiplayer.gd").new()
 var legacy_b: Variant = load("res://scripts/multiplayer.gd").new()
 root.add_child(legacy_a)
 root.add_child(legacy_b)
 legacy_a.address_input.text=endpoint
 legacy_b.address_input.text=endpoint
 legacy_a.create_button.pressed.emit()
 var legacy_created: bool = await until(func(): return not legacy_a.room_code.is_empty())
 check(legacy_created,"unchanged legacy Godot client create works on isolated endpoint")
 if legacy_created:
  legacy_b.code_input.text=legacy_a.room_code
  legacy_b.join_button.pressed.emit()
  check(await until(func(): return not legacy_a.opponent_card.is_empty() and not legacy_b.opponent_card.is_empty()),"unchanged legacy Godot join/started contract survives extension")
  check(legacy_a.server_url==endpoint and legacy_b.server_url==endpoint,"legacy compatibility checks contacted local endpoint only")
 legacy_a.socket.close()
 legacy_b.socket.close()
 legacy_a.queue_free()
 legacy_b.queue_free()
 await process_frame
 print("ANDROID_AUDIO_BLOCKED; ANDROID_TOUCH_BLOCKED; NO_APK_BUILT")
 print("EXTENSION_CHECKS ",checks," FAILURES ",failures.size())
 print("LOCAL_EXTENSION_"+("PASS" if failures.is_empty() else "FAIL"))
 quit(0 if failures.is_empty() else 1)
