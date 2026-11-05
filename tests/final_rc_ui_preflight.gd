extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 if not Engine.is_editor_hint() or root.has_node("DailyRounds") or root.has_node("LiveOps"):quit(1);return
 var ui: Variant=load("res://scripts/photo_duel_extension_ui.gd").new()
 root.add_child(ui)
 await process_frame
 var checks: Array[bool]=[]
 checks.append(ui.voice_adapter.bridge.get_script().resource_path=="res://scripts/android_voice_bridge.gd")
 checks.append(ui.voice_button.disabled)
 checks.append(ui.report_button.disabled and ui.block_button.disabled)
 checks.append(ui.create_button!=null and ui.join_button!=null and ui.terms!=null)
 checks.append(ui.client.service_configuration().get("enabled")==false)
 var state: SceneState=load("res://scenes/Main.tscn").get_state()
 var main_wired:=false
 for index in range(state.get_node_property_count(0)):
  if state.get_node_property_name(0,index)=="script":main_wired=state.get_node_property_value(0,index).resource_path=="res://scripts/main.gd"
 checks.append(main_wired)
 print("NEW_UI_PREFLIGHT ",checks)
 print("Native module preserved; desktop audio disabled; service activation pending; original main scene retained")
 ui.set_process(false);ui.queue_free()
 await process_frame
 quit(0 if not false in checks else 1)
