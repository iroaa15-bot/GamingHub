extends SceneTree
const Powers = preload("res://scripts/qaadet_power_rules.gd")
func _initialize() -> void:
	var p = Powers.new()
	var players: Array[String] = ["a", "b", "c"]
	assert(not p.activate("x", "swap_turn", "a", players, "a")["ok"])
	assert(p.activate("x", "reverse", "a", players)["ok"])
	assert(p.next_player_index(0, 3) == 2)
	assert(not p.activate("x", "reverse", "a", players)["ok"])
	assert(p.activate("y", "shield", "b", players)["ok"])
	assert(p.take_pending("b")["effect"] == "shield")
	assert(p.take_pending("b").is_empty())
	assert(p.activate("z", "swap_turn", "a", players, "b")["requires_validated_followup"])
	print("QAADET_POWER_RULES_SMOKE_PASS")
	quit()
