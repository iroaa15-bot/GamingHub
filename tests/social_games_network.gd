extends SceneTree
const Client=preload("res://scripts/photo_duel_extension_client.gd")
var peers: Array=[]
var failed := false
func _initialize() -> void:call_deferred("run")
func until(check: Callable) -> bool:
 var deadline: int=Time.get_ticks_msec()+9000
 while Time.get_ticks_msec()<deadline:
  if check.call():return true
  await create_timer(.02).timeout
 failed=true
 return false
func peer(category: String) -> Node:
 var value=Client.new();root.add_child(value);peers.append(value)
 value.requested_game="party:"+category;value.authenticate_local=true;value.terms_accepted=true
 value.connect_endpoint("ws://127.0.0.1:8897")
 return value
func run_match(category: String,count: int,full_match: bool=false) -> bool:
 var group: Array=peers.slice(0,count)
 for value in group:
  if value.requested_game!="party:"+category:
   value.requested_game="party:"+category
   value.send_action("duel_hello",{"game_id":value.requested_game})
 if not await until(func():return group.all(func(p):return category in p.capabilities.get("party_games",[]))):return false
 var host=group[0]
 host.send_action("duel_party_create",{"category":category,"players":count,"rounds":10})
 if not await until(func():return not host.code.is_empty()):return false
 for i in range(1,count):group[i].join_room(host.code)
 if not await until(func():return group.all(func(p):return p.state.get("joined",0)==count)):return false
 for value in group:value.send_action("duel_accept",{"config_revision":1,"picture_difficulty":"easy"})
 if not await until(func():return host.state.get("confirmed",[]).count(true)==count):return false
 host.send_action("duel_start")
 if not await until(func():return group.all(func(p):return p.state.get("started",false))):return false
 var used: Dictionary={}
 for round_index in range(10 if full_match else 1):
  var party: Dictionary=host.state.party
  var actor: int=int(party.actor)
  var card: String=str(party.card_id)
  if used.has(card):return false
  used[card]=true
  if category=="open_heart":group[actor].send_action("duel_party_finish",{"card_id":card,"participated":true})
  elif category in ["act_it","show_skill"]:
   for i in range(count):
    if i!=actor:group[i].send_action("duel_party_vote",{"card_id":card,"choice":true})
  elif category=="who_among_us":
   for i in range(count):group[i].send_action("duel_party_vote",{"card_id":card,"choice":str((i+1)%count)})
  elif category=="truth_or_fiction":
   group[actor].send_action("duel_party_story",{"card_id":card,"is_true":true})
   if not await until(func():return group.all(func(p):return bool(p.state.party.get("story_committed",false)))):return false
   for i in range(count):
    if i!=actor:group[i].send_action("duel_party_vote",{"card_id":card,"choice":true})
  elif category=="table_flip":group[actor].send_action("duel_party_power",{"card_id":card,"target":str((actor+1)%count)})
  if not await until(func():return group.all(func(p):return p.state.party.get("phase") in ["results","finished"])):return false
  var scores: Array=host.state.scores
  if not group.all(func(p):return p.state.scores==scores):return false
  if full_match and round_index<9:
   host.send_action("duel_party_next",{"round":round_index+1})
   if not await until(func():return group.all(func(p):return p.state.party.get("phase")=="active" and int(p.state.party.get("round",-1))==round_index+1)):return false
 if full_match and not host.state.get("match_finished",false):return false
 if group.any(func(p):return p.error_count>0):return false
 host.send_action("duel_leave")
 if not await until(func():return group.all(func(p):return p.code.is_empty())):return false
 await create_timer(.75).timeout
 print("SOCIAL_NETWORK_MATCH ",category," players=",count," full_match=",full_match," PASS")
 return true
func run() -> void:
 create_timer(180).timeout.connect(func():print("SOCIAL_NETWORK_TIMEOUT");quit(1))
 root.get_node("PublishedContent").busy=true
 var policy=root.get_node("RoomAudioPolicy");policy.set_music_enabled(false);policy.set_effects_enabled(false)
 for i in range(6):peer("open_heart")
 if not await until(func():return peers.all(func(p):return not p.capabilities.is_empty())):quit(1);return
 for category in ["open_heart","act_it","who_among_us","show_skill","truth_or_fiction","table_flip"]:
  for count in range(2,7):
   if not await run_match(category,count,category=="open_heart" and count==2):
    print("SOCIAL_GAMES_NETWORK FAIL ",category," players=",count);quit(1);return
 for value in peers:value.close_transport();value.queue_free()
 await process_frame
 print("SOCIAL_GAMES_NETWORK PASS thirty real-client room configurations and complete 10-round Open Heart match")
 quit(0)
