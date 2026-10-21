extends SceneTree
func _initialize() -> void:
 var expected := "https://gaminghub-voice-staging.onrender.com"
 var live = load("res://scripts/live_ops.gd").new()
 var pictures = load("res://scripts/daily_ai.gd")
 var rounds = load("res://scripts/daily_rounds.gd")
 var network: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/network_config.json"))
 var ok: bool = live.remote_url == expected + "/liveops/rotation.json"
 ok = ok and pictures.BASE_URL == expected + "/ai_daily"
 ok = ok and rounds.BASE_URL == expected + "/content/history.json"
 ok = ok and network.server_url == "wss://gaminghub-voice-staging.onrender.com"
 live.free()
 if not ok:
  push_error("Staging APK contains an unexpected network endpoint")
  quit(1)
 else:
  print("STAGING_RESOURCES_PASS: game and daily endpoints use existing staging")
  quit(0)
