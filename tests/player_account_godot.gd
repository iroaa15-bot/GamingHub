extends SceneTree
var timeout: SceneTreeTimer
func _initialize() -> void: call_deferred("run")
func run() -> void:
 timeout=create_timer(20)
 timeout.timeout.connect(func(): print("ACCOUNT_CLIENT_TIMEOUT"); quit(1))
 var client=load("res://scripts/player_account_client.gd").new()
 client.name="PlayerAccountSession"
 root.add_child(client)
 var ui=load("res://scripts/player_account_ui.gd").new()
 root.add_child(ui)
 var valid=not ui.get_property_list().any(func(p: Dictionary):return p.name=="admin") and load("res://scripts/main.gd").can_instantiate()
 client.request("/auth/guest",{"name":"Godot integration test"})
 var response=await client.changed
 valid=valid and response[2] and not client.token.is_empty() and bool(client.user.get("guest",false))
 client.request("/me",{},false)
 response=await client.changed
 valid=valid and response[2] and response[1].has("progress")
 client.request("/auth/logout")
 response=await client.changed
 valid=valid and response[2] and client.token.is_empty()
 print("PLAYER_ACCOUNT_GODOT_HTTP ",valid," — local service; OAuth/remote hosting not configured")
 ui.queue_free()
 client.queue_free()
 await process_frame
 quit(0 if valid else 1)
