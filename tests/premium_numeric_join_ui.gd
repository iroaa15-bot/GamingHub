extends SceneTree
func _initialize():call_deferred("run")
func wait_for(check: Callable):
 var until=Time.get_ticks_msec()+6000
 while not check.call() and Time.get_ticks_msec()<until:await create_timer(.03).timeout
 return check.call()
func run():
 create_timer(16).timeout.connect(func():print("NUMERIC_UI_TIMEOUT");quit(2))
 var code=preload("res://scripts/room_invite_code.gd")
 for value in ["123456","١٧٦٠٣٠","۱۲۳۴۵۶","12-34 56","AB12EF34"]:assert(code.valid(value))
 for value in ["12345","1234567","12AB34","123456789","ABCDEF01X","<123456>"]:assert(not code.valid(value))
 assert(code.valid("YIYWCI",true));assert(code.valid("١٢٣٤٥٦",true));assert(not code.valid("AB12EF34",true))
 print("INVITE_NORMALIZATION_LEGACY_COMPAT true")
 assert(load("res://scripts/multiplayer.gd").can_instantiate())
 var script=load("res://scripts/shared_quiz_ui.gd");script.selected_game="6"
 var a=script.new();root.add_child(a);var b=script.new();root.add_child(b);b.hide()
 a.endpoint_field.text="ws://127.0.0.1:8886";a.terms.button_pressed=true;a._request_room_action("create")
 assert(await wait_for(func():return a.client.code.length()==6))
 b.endpoint_field.text="ws://127.0.0.1:8886";b.terms.button_pressed=true
 var localized=""
 for character in a.client.code:localized+="٠١٢٣٤٥٦٧٨٩"[int(character)]
 b.code_field.text=localized;b._request_room_action("join")
 assert(await wait_for(func():return a.client.state.get("joined",0)==2 and b.client.state.get("joined",0)==2))
 assert(a.client.code==b.client.code)
 print("REAL_NUMERIC_UI_JOIN_ARABIC_DIGITS true")
 a.client.send_action("duel_leave");a.queue_free();b.queue_free();await process_frame;quit()
