extends SceneTree
const Fixture=preload("res://tests/open_heart_play_view.gd")
var failed:=false
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
 if not value:failed=true;push_error(message)
func run() -> void:
 root.get_node("PublishedContent").busy=true
 root.get_node("GamingHubAccount").api_base=""
 root.get_node("RoomAudioPolicy").set_music_enabled(false)
 root.get_node("RoomAudioPolicy").set_effects_enabled(false)
 var script=load("res://scripts/social_room_ui.gd")
 for category in script.SOCIAL_TITLES:
  script.selected_social=category
  var ui=script.new();root.add_child(ui);await process_frame
  var transport=ui.client
  ui.client=Fixture.RecordingClient.new();root.add_child(ui.client)
  ui.client.code="654321";ui.client.player=1
  ui.client.capabilities={"voice":true,"room_agreement":true}
  var state: Dictionary={"capacity":3,"joined":3,"connected":[true,true,true],"scores":[0,0,0],"profiles":[],"started":true,"room_agreement":true,"primary_mode":"voice","timer":30 if category in ["act_it","show_skill"] else 0,"party":{"phase":"active","actor":"0","round":0,"rounds":10,"category":category,"card_id":"secret-card","card":null,"voted_players":[],"story_committed":false,"choosing":false,"power":"steal"}}
  ui.client.state=state;ui._state(state)
  if category in ["act_it","show_skill"]:
   check(ui.play_view.prompt.text.contains("سري"),"performer card stays private")
   check(ui.clock.visible,"real performance timer is shown")
  if category=="truth_or_fiction":
   check(ui.play_view.options.is_empty(),"no vote before secret commitment")
   state.party.story_committed=true;ui.client.state=state;ui._state(state)
   check(ui.play_view.options.size()==2,"vote appears after commitment")
  if category in ["act_it","show_skill","truth_or_fiction","who_among_us"]:
   var before: int=ui.client.sent.size()
   ui.play_view.submit_option(0);ui.play_view.submit_option(0)
   check(ui.client.sent.size()==before+1,"social vote double tap is locked")
   check(ui.client.sent[-1].type=="duel_party_vote" and ui.client.sent[-1].fields.card_id=="secret-card","vote includes current card identity")
   state.party.voted_players=["2"];ui.client.state=state;ui._state(state)
   check(not ui.play_view.pending_key.is_empty(),"another player's vote cannot acknowledge ours")
   state.party.voted_players=["1","2"];ui.client.state=state;ui._state(state)
   check(ui.play_view.pending_key.is_empty() and ui.play_view.options.is_empty(),"own confirmed vote ends input")
  if category=="table_flip":
   state.party.choosing=true;state.party.offered=[];ui.client.state=state;ui._state(state)
   check(ui.play_view.options.is_empty(),"private offers are not invented for observers")
   ui.client.player=0;state.party.offered=[{"id":"offered-a","text_ar":"كارت أ"},{"id":"offered-b","text_ar":"كارت ب"}]
   ui.client.state=state;ui._state(state);ui.play_view.submit_option(1)
   check(ui.client.sent[-1].type=="duel_party_choose" and ui.client.sent[-1].fields.card_id=="offered-b","power choice preserves actual offered ID")
  ui.client.queue_free();ui.client=transport;ui.queue_free();await process_frame
 print("SOCIAL_PLAY_ACTIONS_PASS="+str(not failed)+" private prompts, secret commitment, vote acknowledgement, power selection, duplicate lock")
 quit(1 if failed else 0)
