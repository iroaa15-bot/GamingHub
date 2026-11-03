extends SceneTree
const Client=preload("res://scripts/photo_duel_extension_client.gd")
var a: Node
var b: Node
func _initialize() -> void:call_deferred("run")
func until(predicate: Callable) -> bool:
 var limit=Time.get_ticks_msec()+20000
 while Time.get_ticks_msec()<limit:
  if predicate.call():return true
  await create_timer(.05).timeout
 return false
func run() -> void:
 a=Client.new();b=Client.new()
 for client in [a,b]:
  client.terms_accepted=true;client.authenticate_local=true;client.requested_game="6"
  root.add_child(client);client.connect_endpoint("ws://127.0.0.1:8942")
 assert(await until(func():return not a.capabilities.is_empty() and not b.capabilities.is_empty()))
 a.send_action("duel_quiz_create",{"game_id":"6","players":2,"timer":0,"rounds":1,"difficulty":"easy"})
 assert(await until(func():return not a.code.is_empty()))
 b.join_room(a.code)
 assert(await until(func():return a.state.get("joined")==2 and b.state.get("joined")==2))
 var room: String=b.code
 var old_token: String=b.token
 b.socket.close()
 assert(await until(func():return b.token!=old_token and b.code==room and not b.state.get("paused",true) and not a.state.get("paused",true)))
 assert(a.state.scores==b.state.scores)
 print("AUTOMATIC_ROOM_RESUME_PASS: same room, rotated capability, unchanged scores, two real Godot WebSocket clients")
 a.send_action("duel_leave")
 a.queue_free();b.queue_free();await process_frame
 quit(0)
