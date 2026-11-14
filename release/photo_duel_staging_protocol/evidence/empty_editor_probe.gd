extends SceneTree
func _initialize() -> void:
 call_deferred("finish")
func finish() -> void:
 await create_timer(3).timeout
 print("EMPTY_EDITOR_PROBE_NO_GAME_CLIENTS")
 quit(0)
