extends SceneTree
# Runs against the isolated staging export copy, without connecting to production.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/Multiplayer.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if game.server_url != "wss://gaminghub-recovery-staging.onrender.com":
		push_error("Staging profile did not select the staging voice server")
		quit(1)
		return
	game.queue_free()
	await process_frame
	print("VOICE_STAGING_PROFILE_PASS: multiplayer selects the isolated staging endpoint")
	quit(0)
