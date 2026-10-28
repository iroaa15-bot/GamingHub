extends SceneTree
var a
var b
var failures=[]
var folder="user://simple_room_captures"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,name: String) -> void:
 print("SIMPLE_ROOM_CHECK ",name," ",ok)
 if not ok:failures.append(name)
func until(predicate: Callable) -> bool:
 var end=Time.get_ticks_msec()+6000
 while Time.get_ticks_msec()<end:
  if predicate.call():return true
  await create_timer(.025).timeout
 return false
func snap(name: String) -> void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func peer() -> Node:
 var ui=load("res://scripts/photo_duel_extension_ui.gd").new();root.add_child(ui);ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);return ui
func run() -> void:
 create_timer(30).timeout.connect(func():print("SIMPLE_ROOM_TIMEOUT");quit(1))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.content_scale_size=Vector2i(420,900)
 a=peer();b=peer();b.hide()
 check(not a.endpoint_field.is_visible_in_tree(),"technical endpoint absent from normal landing")
 await snap("simple-room-landing")
 a.endpoint_field.text="ws://127.0.0.1:8883"
 a._request_room_action("create")
 check(a.client.code.is_empty() and a.client.capabilities.is_empty(),"room terms required before connection")
 a.terms.button_pressed=true
 a._request_room_action("create")
 check(await until(func():return not a.client.code.is_empty()),"one create action authenticates connects and creates")
 check(a._invite_box.is_visible_in_tree() and a._invite_code.text==a.client.code,"server generated code visible")
 a._copy_room_code()
 await process_frame
 var copy_ok: bool=DisplayServer.clipboard_get()==a.client.code
 print("SYSTEM_CLIPBOARD_COPY ",copy_ok," (false = platform verification BLOCKED, not a successful copy)")
 check(copy_ok or a._invite_code.has_selection(),"manual selectable-code fallback when clipboard unavailable")
 await snap("simple-room-created")
 b.endpoint_field.text="ws://127.0.0.1:8883";b.terms.button_pressed=true
 b.code_field.text="bad";b._request_room_action("join")
 check(b.client.capabilities.is_empty(),"invalid code rejected before connection")
 b.code_field.text=" "+a.client.code.to_lower()+" "
 b._request_room_action("join")
 check(await until(func():return b.client.code==a.client.code and a.client.state.get("joined",0)==2),"one code join authenticates and joins real room")
 check(b.client.state.picture_difficulty==a.client.state.picture_difficulty and b._online_rank.disabled,"joining preserves read only host difficulty")
 check(not b._online_category.is_editable() if b._online_category.has_method("is_editable") else b._online_category.disabled,"guest cannot change host category")
 a.hide();b.show();await snap("simple-room-joined")
 a.client.send_action("duel_leave")
 await until(func():return b.client.state.get("closed",false))
 for ui in [a,b]:ui.client.close_transport();ui.queue_free()
 await process_frame
 print("SIMPLE_ROOM_REAL_UI_WS ",failures.is_empty()," ",failures)
 quit(0 if failures.is_empty() else 1)
