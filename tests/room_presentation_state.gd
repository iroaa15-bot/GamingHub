extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.get_node("PublishedContent").busy=true
 root.get_node("RoomAudioPolicy").set_music_enabled(false)
 root.get_node("RoomAudioPolicy").set_effects_enabled(false)
 var room=load("res://scripts/photo_duel_extension_ui.gd").new()
 root.add_child(room)
 room.client.capabilities={"moderation":true}
 room.client.player=0
 room.client.code="TEST01"
 var opponents=[]
 for i in range(1,6): opponents.append({"player":i,"image":"res://assets/generated/lion.webp"})
 room._state({"capacity":6,"joined":6,"connected":[true,true,true,true,false,true],"started":true,"current":0,"responder":1,"scores":[2,4,0,1,0,3],"opponents":opponents})
 var valid=room._seats.columns==3 and room._seat_labels.size()==6 and room._seat_labels[4].text.contains("0")
 var visible_images=0
 for image in room.images:
  if image.visible: visible_images+=1
 valid=valid and visible_images==1 and room.images[1].visible and not room.images[0].visible
 print("ROOM_ACTIVE_FIXTURE ",valid," images=",visible_images)
 room._state({"capacity":2,"joined":1,"connected":[true,false],"started":false})
 valid=valid and room._seat_panels[0].visible and not room._seat_panels[2].visible
 room.client.code=""
 room._state({"capacity":2,"joined":2,"connected":[false,false],"started":true,"closed":true,"match_finished":true,"winner":0,"scores":[1,0],"remaining_ms":12000,"opponents":opponents,"pending":{"kind":"question","text":"Stale question","responder":0},"awaiting_next_round":true})
 valid=valid and not room._scores.visible and not room.status.text.contains("الفائز")
 valid=valid and not room.clock.visible and not room._clock_bar.visible and not room._duel_next.visible and not room.question_label.visible
 for image in room.images:valid=valid and not image.visible
 for caption in room.captions:valid=valid and not caption.visible
 valid=valid and not room._match_controls.visible and not room._room_started
 print("ROOM_CLOSED_FIXTURE clock=",room.clock.visible," bar=",room._clock_bar.visible," next=",room._duel_next.visible," question=",room.question_label.visible," controls=",room._match_controls.visible)
 print("ROOM_PRESENTATION_STATE ",valid," — UI fixture only; no multiplayer claim")
 room.queue_free()
 await process_frame
 var quiz=load("res://scripts/shared_quiz_ui.gd").new();root.add_child(quiz);await process_frame
 quiz.client.code=""
 quiz._state({"started":true,"closed":true,"quiz":{"phase":"question","question":{"id":"old","ar":"سؤال قديم","en":"Old question"}}})
 valid=valid and not quiz.clock.visible and not quiz._clock_bar.visible and not quiz.quiz_panel.visible
 quiz.queue_free();await process_frame
 quit(0 if valid else 1)
