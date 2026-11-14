extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var room=load("res://scripts/multiplayer.gd").new()
 root.add_child(room)
 var qs=[]
 for q in room.catalog.get("questions",[]): qs.append(str(q.get("ar","")))
 room._handle({"type":"started","room":"UI2P","player_index":0,"resume_token":"ui-fixture-only","opponent_card":{"name":"Elephant"},"questions_ar":qs,"questions":qs,"your_turn":true})
 await process_frame
 var valid=room._room_toolbar.visible and not room.output.get_node("CompactHeader").visible and not room.lobby_controls.visible
 valid=valid and is_instance_valid(room.card_art.texture) and room._guess_toggle.get_signal_connection_list("pressed").size()==1 and room._questions_toggle.get_signal_connection_list("pressed").size()==1
 valid=valid and not room._guess_panel.visible and not room._questions_panel.visible and not room._candidates_panel.visible
 room._show_guess=true
 room._apply_action_panels()
 valid=valid and room._guess_panel.visible and is_instance_valid(room.guess_input)
 room._show_questions=true
 room._apply_action_panels()
 valid=valid and room._questions_panel.visible
 for i in range(3):
  room._refresh_actions()
  await process_frame
 valid=valid and room.voice_button.get_parent()==room._room_toolbar
 room.my_turn=false
 room._refresh_actions()
 await process_frame
 valid=valid and room._guess_toggle.disabled and room._questions_toggle.disabled
 print("CLASSIC_MATCH_LAYOUT ",valid," — presentation fixture only; no network/audio test")
 room.queue_free()
 await process_frame
 quit(0 if valid else 1)
