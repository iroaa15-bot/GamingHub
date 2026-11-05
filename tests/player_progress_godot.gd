extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 create_timer(20).timeout.connect(func(): print("PLAYER_PROGRESS_TIMEOUT"); quit(1))
 var client=load("res://scripts/player_account_client.gd").new()
 root.add_child(client)
 var unique := Crypto.new().generate_random_bytes(16).hex_encode()
 client.request("/auth/register",{"name":"Progress integration test","email":unique+"@example.test","password":Crypto.new().generate_random_bytes(24).hex_encode()})
 var response=await client.changed
 var valid: bool=response[2] and not bool(client.user.get("guest",true))
 client.sync_progress({"xp":7,"wins":1,"matches":2,"picture_wins":1})
 response=await client.changed
 valid=valid and response[2] and int(response[1].get("progress",{}).get("xp",-1))==7
 client.request("/me",{},false)
 response=await client.changed
 valid=valid and response[2] and int(response[1].get("progress",{}).get("matches",-1))==2
 print("PLAYER_PROGRESS_GODOT_HTTP ",valid," — personal client-reported counters only")
 client.queue_free()
 await process_frame
 quit(0 if valid else 1)
