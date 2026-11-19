extends SceneTree
func _initialize() -> void:call_deferred("run")
func until(check: Callable) -> bool:
 var deadline: int=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  if check.call():return true
  await create_timer(.02).timeout
 return false
func run() -> void:
 create_timer(50).timeout.connect(func():print("SOCIAL_ROOM_UI_NETWORK TIMEOUT");quit(1))
 root.get_node("PublishedContent").busy=true
 root.get_node("GamingHubAccount").api_base=""
 var policy=root.get_node("RoomAudioPolicy");policy.set_music_enabled(false);policy.set_effects_enabled(false)
 var script=load("res://scripts/social_room_ui.gd");script.selected_social="open_heart"
 var a=script.new();root.add_child(a);await process_frame
 var b=script.new();root.add_child(b);await process_frame
 a.terms.set_pressed_no_signal(true);b.terms.set_pressed_no_signal(true)
 a._request_room_action("create")
 var valid: bool=await until(func():return not a.client.code.is_empty())
 print("SOCIAL_UI_STAGE create=",valid)
 if valid:
  b.code_field.text=a.client.code;b._request_room_action("join")
  valid=await until(func():return b.client.state.get("joined",0)==2 and a.client.state.get("joined",0)==2)
  print("SOCIAL_UI_STAGE join=",valid)
 if valid:
  a._accept_configuration();b._accept_configuration()
  valid=await until(func():return a.client.state.get("party",{}).get("phase")=="active" and b.client.state.get("party",{}).get("phase")=="active")
  print("SOCIAL_UI_STAGE start=",valid)
 if valid:
  valid=a.client.requested_game=="party:open_heart" and b.client.requested_game=="party:open_heart"
  valid=valid and not a._match_controls.visible and not b._match_controls.visible
  valid=valid and a._seats.is_visible_in_tree() and b._seats.is_visible_in_tree()
  var controls: Array=[a.play_view.participate,a.play_view.skip]
  valid=valid and controls.size()==2
  print("SOCIAL_UI_STAGE controls=",valid," count=",controls.size())
  if valid:
   controls[0].pressed.emit()
   controls[0].pressed.emit() # Same-frame repeat must not submit twice.
  valid=valid and await until(func():return a.client.state.party.phase=="results" and b.client.state.party.phase=="results")
  valid=valid and int(a.client.state.scores[0])==10 and int(a.client.state.scores[1])==0 and a.client.state.scores==b.client.state.scores
  valid=valid and a._seats.is_visible_in_tree() and a.play_view.title.text.contains("1/10")
  print("SOCIAL_UI_STAGE results=",valid," scores=",a.client.state.scores," peer_scores=",b.client.state.scores)
 if valid:
  for round_index in range(1,10):
   a.play_view.next_round.pressed.emit()
   valid=valid and await until(func():return a.client.state.party.phase=="active" and b.client.state.party.phase=="active")
   var actor=a if str(a.client.state.party.actor)==str(a.client.player) else b
   actor.play_view.participate.pressed.emit()
   valid=valid and await until(func():return a.client.state.party.phase in ["results","finished"] and b.client.state.party.phase==a.client.state.party.phase)
   if not valid:break
  valid=valid and a.client.state.party.phase=="finished" and a.client.state.scores==[50,50] and b.client.state.scores==[50,50]
  print("SOCIAL_UI_FULL_MATCH ",valid," ten rounds, duplicate tap locked, scores=",a.client.state.scores)
 a.client.send_action("duel_leave")
 await until(func():return a.client.code.is_empty() and b.client.code.is_empty())
 valid=valid and not a.party_panel.visible and not b.party_panel.visible
 valid=valid and a.client.error_count==0 and b.client.error_count==0
 print("SOCIAL_UI_STAGE errors=",a.client.error_count," ",b.client.error_count," valid=",valid)
 a._pending_room_action="create";a._room_protocol_ready({"party_games":[]})
 valid=valid and a._pending_room_action.is_empty() and a.client.code.is_empty()
 a.client.close_transport();b.client.close_transport();a.queue_free();b.queue_free();await process_frame
 print("SOCIAL_ROOM_UI_NETWORK ",valid," common handshake, capability gate, UI create/join/start, button sends server-scored participation")
 quit(0 if valid else 1)
