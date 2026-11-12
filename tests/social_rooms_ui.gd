extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.get_node("PublishedContent").busy=true
 var auth=root.get_node("GamingHubAccount");auth.api_base=""
 var policy=root.get_node("RoomAudioPolicy");policy.set_music_enabled(false);policy.set_effects_enabled(false)
 var script=load("res://scripts/social_room_ui.gd")
 var valid: bool=true
 var cases: int=0
 for language in ["ar","en"]:
  for category in script.SOCIAL_TITLES:
   script.selected_social=category
   var view=script.new();root.add_child(view);await process_frame
   view.language=language;view.client.code="123456"
   view.client.capabilities={"voice":true,"room_agreement":true,"party_games":script.SOCIAL_TITLES.keys(),"primary_modes":["voice","text","mixed","tap"]}
   for count in range(2,7):
    for player in [0,count-1]:
     view.client.player=player
     var state={"code":"123456","capacity":count,"joined":count,"connected":[],"scores":[],"confirmed":[],"profiles":[],"player":player,"current":0,"host":0,"responder":1,"started":true,"room_agreement":true,"primary_mode":"voice","config_revision":1,"picture_difficulty":"easy","opponents":[],"preset_questions":[],"party":{"category":category,"phase":"active","actor":"0","round":0,"rounds":10,"card_id":"fixture","card":{"id":"fixture","text_ar":"كارت اختبار","text_en":"Test card"},"voted_players":[],"story_committed":false,"power":"bonus"}}
     for i in range(count):state.connected.append(true);state.scores.append(0);state.confirmed.append(true)
     view._state(state);await process_frame
     valid=valid and not view._match_controls.visible and view.party_panel.visible
     valid=valid and view._seats.is_visible_in_tree() and view._seats.get_parent()==view.party_panel
     var expected: int=0
     if category=="open_heart":expected=2 if player==0 else 0
     elif category=="who_among_us":expected=count-1
     elif category in ["act_it","show_skill"]:expected=0 if player==0 else 2
     elif category=="truth_or_fiction":expected=2 if player==0 else 0
     elif category=="table_flip":expected=count-1 if player==0 else 0
     var buttons: Array=view.party_panel.find_children("*","Button",true,false)
     valid=valid and buttons.size()==expected
     state.paused=true;view._state(state)
     valid=valid and view._seats.is_visible_in_tree()
     for control in view.party_panel.find_children("*","Button",true,false):valid=valid and control.disabled
     cases+=1
   view.queue_free();await process_frame
 print("SOCIAL_ROOMS_UI ",valid," cases=",cases," AR/EN, 2-6 players, actor/voter controls, pause disables actions, photo controls hidden")
 quit(0 if valid else 1)
