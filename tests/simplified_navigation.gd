extends SceneTree
class CreationClient:
 extends "res://scripts/photo_duel_extension_client.gd"
 var sent: Dictionary={}
 func send_action(_kind: String,fields: Dictionary={}) -> Error:
  sent=fields
  return OK
func _initialize() -> void:call_deferred("run")
func run() -> void:
 create_timer(25).timeout.connect(func():push_error("Navigation test timeout");quit(1))
 root.get_node("PublishedContent").busy=true
 var creation:=CreationClient.new()
 creation.capabilities={"room_agreement":true,"simple_rounds":true,"picture_filters":true}
 creation.create_room(2,0,3,{"manual_rounds":true,"picture_difficulty":"easy"})
 assert(creation.sent.manual_rounds and creation.sent.room_agreement and creation.sent.picture_difficulty=="easy")
 creation.capabilities.erase("simple_rounds")
 creation.create_room(2,0,3,{"manual_rounds":true})
 assert(not creation.sent.has("manual_rounds"))
 creation.free()
 var room=load("res://scripts/photo_duel_extension_ui.gd").new()
 root.add_child(room)
 await process_frame
 assert(room._entry_choices.visible and room._entry_choices.get_child_count()==2)
 assert(room._connection_message("Room unavailable").contains("الغرفة غير متاحة") if room.language=="ar" else room._connection_message("Room unavailable").begins_with("Room unavailable"))
 assert(not room._lobby_controls.visible and not room._settings_toggle.visible)
 room._focus_room_entry("join")
 assert(room.code_field.visible and room.join_button.visible and not room.create_button.visible)
 assert(not room._settings_body.visible and not room._online_filter_box.visible)
 room._focus_room_entry("create")
 assert(room.create_button.visible and not room.code_field.visible and not room.join_button.visible)
 room.client.code="123456";room.client.player=0
 room.client.capabilities={"room_agreement":true,"primary_modes":["voice","text","mixed","tap"]}
 var state={"capacity":2,"joined":2,"connected":[true,true],"started":true,"current":0,"responder":1,"scores":[0,0],"primary_mode":"mixed","opponents":[],"room_agreement":true,"config_revision":1}
 room._state(state)
 assert(not room._settings_toggle.visible and not room._settings_body.visible)
 state.paused=true;room._state(state)
 assert(not room._settings_toggle.visible and not room._settings_body.visible)
 state.paused=false;room._state(state)
 assert(room._mode_field.selected==2)
 room._mode_field.select(1)
 room._state(state)
 assert(room._mode_field.selected==1)
 state.config_revision=2
 room._state(state)
 assert(room._mode_field.selected==2)
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
 var scroll:=ScrollContainer.new();scroll.size=Vector2(400,220);root.add_child(scroll)
 var list:=VBoxContainer.new();scroll.add_child(list)
 var moves: Array=[]
 for index in range(3):
  var row=load("res://scripts/order_drag_item.gd").new()
  row.text=str(index);row.item_index=index;row.group_key="touch-test";row.ordering_enabled=true
  row.custom_minimum_size=Vector2(350,100);list.add_child(row)
  row.move_requested.connect(func(source,target):moves.append([source,target]))
 await process_frame;await process_frame
 scroll.scroll_vertical=50
 await process_frame
 var press:=InputEventScreenTouch.new();press.index=0;press.pressed=true;press.position=Vector2(100,110)
 root.push_input(press,true)
 var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(100,25);drag.relative=Vector2(0,-85)
 root.push_input(drag,true)
 var release:=InputEventScreenTouch.new();release.index=0;release.position=drag.position
 root.push_input(release,true)
 await process_frame
 assert(moves==[[1,0]] and scroll.scroll_vertical==50)
 root.push_input(press,true);root.push_input(drag,true)
 release.canceled=true;root.push_input(release,true)
 assert(moves.size()==1)
 # A row clipped by the scroll viewport cannot capture an unrelated touch.
 assert(not list.get_child(2)._contains_touch(Vector2(100,260)))
 var mouse:=InputEventMouseButton.new();mouse.device=InputEvent.DEVICE_ID_EMULATION
 mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;mouse.position=press.position
 root.push_input(mouse,true);root.push_input(press,true)
 var motion:=InputEventMouseMotion.new();motion.device=InputEvent.DEVICE_ID_EMULATION
 motion.position=drag.position;motion.relative=drag.relative
 root.push_input(motion,true);root.push_input(drag,true)
 mouse.pressed=false;mouse.position=drag.position;root.push_input(mouse,true)
 release.canceled=false;root.push_input(release,true)
 assert(moves==[[1,0],[1,0]] and scroll.scroll_vertical==50)
 scroll.queue_free();await process_frame
 print("SIMPLIFIED_NAVIGATION_PASS — UI role fixtures and local drag logic; not a phone test")
 quit(0)
