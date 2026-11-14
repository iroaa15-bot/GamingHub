extends SceneTree
const Client=preload("res://scripts/photo_duel_extension_client.gd")
var peers=[]
var failures=[]
func _initialize():call_deferred("run")
func check(ok: bool,name: String):
 print("APPROVED_ROOM ",name," ",ok)
 if not ok:failures.append(name)
func until(predicate: Callable) -> bool:
 var end=Time.get_ticks_msec()+5000
 while Time.get_ticks_msec()<end:
  if predicate.call():return true
  await create_timer(.025).timeout
 return false
func run():
 create_timer(40).timeout.connect(func():quit(2))
 for i in range(6):
  var peer=Client.new();root.add_child(peer);peers.append(peer);peer.connect_endpoint("ws://127.0.0.1:8894")
 check(await until(func():return peers.all(func(p):return p.capabilities.get("picture_filters",false))),"six actual Godot transports")
 for count in [2,3,4,5,6]:
  var group=peers.slice(0,count)
  peers[0].create_room(count,0,1,{"picture_category":"transport","picture_difficulty":"all"})
  check(await until(func():return not peers[0].code.is_empty()),"created "+str(count))
  var code: String=peers[0].code
  check(code.length()==6 and code.is_valid_int(),"numeric code "+str(count))
  for i in range(1,count):group[i].join_room(code)
  check(await until(func():return group.all(func(p):return p.state.get("started",false))),"joined and synchronized "+str(count))
  for p in group:
   for opponent in p.state.opponents:
    check(str(opponent.image).begins_with("res://assets/imported_photos/") and ResourceLoader.exists(opponent.image),"actual approved resource available and synchronized")
  peers[0].send_action("duel_leave")
  await until(func():return group.all(func(p):return p.code.is_empty()))
  await create_timer(.1).timeout
 for p in peers:p.close_transport();p.queue_free()
 await process_frame
 print("APPROVED_ROOMS_REAL_GODOT_WS ",failures.is_empty()," ",failures)
 quit(0 if failures.is_empty() else 1)

