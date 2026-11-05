extends SceneTree
const Client=preload("res://scripts/photo_duel_extension_client.gd")
var nodes=[]
func _initialize() -> void: call_deferred("run")
func until(predicate: Callable) -> bool:
 var end=Time.get_ticks_msec()+6000
 while Time.get_ticks_msec()<end:
  if predicate.call(): return true
  await create_timer(.025).timeout
 return false
func peer() -> Node:
 var c=Client.new();root.add_child(c);nodes.append(c);c.connect_endpoint("ws://127.0.0.1:8881");return c
func run() -> void:
 create_timer(25).timeout.connect(func(): print("FILTER_NETWORK_TIMEOUT");quit(1))
 var a=peer();var b=peer()
 var valid=await until(func(): return bool(a.capabilities.get("picture_filters",false)) and bool(b.capabilities.get("picture_filters",false)))
 a.create_room(2,30,10,{"picture_category":"fruits","picture_difficulty":"hard"})
 valid=valid and await until(func(): return not a.code.is_empty())
 b.join_room(a.code)
 valid=valid and await until(func(): return bool(a.state.get("started",false)) and bool(b.state.get("started",false)))
 var metadata=JSON.parse_string(FileAccess.get_file_as_string("res://data/picture_filters.json"))
 var cards=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json")).cards
 var by_asset={}
 for card in cards: by_asset["res://assets/generated/"+card.image+".webp"]=metadata.items[card.name]
 for c in [a,b]:
  valid=valid and c.state.get("picture_category")=="fruits" and c.state.get("picture_difficulty")=="hard"
  for opponent in c.state.get("opponents",[]): valid=valid and by_asset[opponent.image].category=="fruits" and by_asset[opponent.image].difficulty=="hard"
 var limited=peer()
 valid=valid and await until(func(): return not limited.capabilities.is_empty())
 limited.create_room(6,30,10,{"picture_category":"science","picture_difficulty":"all"})
 valid=valid and await until(func(): return not limited.last_error.is_empty())
 valid=valid and limited.code.is_empty()
 print("PICTURE_FILTER_REAL_GODOT_WS ",valid," — real loopback service/clients; not production online PASS")
 for c in nodes: c.close_transport();c.queue_free()
 await process_frame
 quit(0 if valid else 1)
