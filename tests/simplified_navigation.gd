extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 create_timer(25).timeout.connect(func():push_error("Navigation test timeout");quit(1))
 root.get_node("PublishedContent").busy=true
 var room=load("res://scripts/photo_duel_extension_ui.gd").new()
 root.add_child(room)
 await process_frame
 assert(room._entry_choices.visible and room._entry_choices.get_child_count()==2)
 assert(not room._lobby_controls.visible and not room._settings_toggle.visible)
 room._focus_room_entry("join")
 assert(room.code_field.visible and room.join_button.visible and not room.create_button.visible)
 assert(not room._settings_body.visible and not room._online_filter_box.visible)
 room._focus_room_entry("create")
 assert(room.create_button.visible and not room.code_field.visible and not room.join_button.visible)
 room.client.code="123456";room.client.player=0
 room.client.capabilities={"room_agreement":true,"primary_modes":["voice","text","mixed","tap"]}
 var state={"capacity":2,"joined":2,"connected":[true,true],"started":true,"current":0,"responder":1,"scores":[0,0],"primary_mode":"mixed","opponents":[]}
 room._state(state)
 assert(room.question_field.visible and not room.yes_button.visible and not room.correct_button.visible)
 state.pending={"kind":"question","mode":"text","text":"A question","responder":1}
 room.client.player=1;room._state(state)
 assert(room.yes_button.visible and room.no_button.visible and not room.question_field.visible and not room.correct_button.visible)
 state.pending={"kind":"guess","text":"A final guess","responder":1};room._state(state)
 assert(not room.yes_button.visible and room.correct_button.visible)
 room.queue_free();await process_frame
 var main=load("res://scripts/main.gd").new();root.add_child(main)
 var edit:=LineEdit.new();main.add_child(edit);edit.grab_focus()
 assert(main.get_viewport().gui_get_focus_owner()==edit)
 var generation: int=main.ui_action_generation
 main._queue_back_navigation()
 assert(main.get_viewport().gui_get_focus_owner()!=edit and main.ui_action_generation==generation)
 assert(load("res://scripts/visual_skin.gd").dismiss_text_input(main.get_viewport()))
 await process_frame
 assert(not load("res://scripts/visual_skin.gd").dismiss_text_input(main.get_viewport()))
 main.sound_enabled=false;main.round_finished=false;main.question_index=0
 main.clear_ui();main.show_order_choices({"steps_"+main.selected_language:["First","Second","Third"]})
 assert(main.order_picks.size()==3)
 var source: int=main.order_picks[0];var target: int=main.order_picks[2]
 main._move_local_order(source,target)
 assert(main.order_picks[2]==source)
 for control in main.order_buttons:assert(control.ordering_enabled)
 main.round_finished=true
 var before=main.order_picks.duplicate();main._move_local_order(source,target)
 assert(main.order_picks==before)
 main.queue_free();await process_frame
 print("SIMPLIFIED_NAVIGATION_PASS — UI role fixtures and local drag logic; not a phone test")
 quit(0)
