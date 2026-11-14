extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 create_timer(10).timeout.connect(func(): print("FILTER_COMPAT_TIMEOUT");quit(1))
 var c=load("res://scripts/photo_duel_extension_client.gd").new();root.add_child(c)
 c.connect_endpoint("ws://127.0.0.1:8881")
 while c.capabilities.is_empty(): await create_timer(.025).timeout
 c.create_room(2,30,10)
 while c.state.is_empty(): await create_timer(.025).timeout
 var valid=c.state.get("picture_category")=="all" and c.state.get("picture_difficulty")=="all"
 var ui=load("res://scripts/photo_duel_extension_ui.gd").new();root.add_child(ui)
 ui.client.capabilities=c.capabilities
 ui._state({})
 valid=valid and ui._online_filter_box.visible and ui._online_category.item_count==14 and ui._online_rank.item_count==4
 print("PICTURE_FILTER_DEFAULT_COMPAT ",valid," — original create payload and capability-gated UI")
 ui.queue_free();c.close_transport();c.queue_free();await process_frame
 quit(0 if valid else 1)
