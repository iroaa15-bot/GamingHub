extends SceneTree

const PlayerPrefs = preload("res://scripts/player_preferences.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var expected := args[1]
	if args[0] == "save":
		PlayerPrefs.save_language(expected)
	var actual := PlayerPrefs.language()
	if actual != expected:
		push_error("Expected language %s, found %s" % [expected, actual])
		quit(1)
		return
	print("LANGUAGE_RESTART_PASS ", expected)
	quit()
