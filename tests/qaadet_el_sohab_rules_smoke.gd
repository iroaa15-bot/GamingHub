extends SceneTree

const Engine = preload("res://scripts/qaadet_el_sohab_engine.gd")

func _initialize() -> void:
	var e = Engine.new()
	var cards: Array[Dictionary] = [
		{"id": "a", "category": "open_heart"},
		{"id": "b", "category": "act_it"},
		{"id": "c", "category": "who_among_us"},
		{"id": "d", "category": "truth_or_fiction"}
	]
	assert(not e.setup(["a"], cards))
	assert(not e.setup(["a", "a"], cards))
	assert(e.setup(["a", "b", "c"], cards, 10, 42))
	assert(e.draw_next("open_heart")["id"] == "a")
	assert(e.draw_next().is_empty()) # Cannot draw over unresolved card
	assert(e.resolve_round()["awards"]["a"] == 10)
	assert(e.draw_next("open_heart").is_empty()) # No repeats
	assert(e.draw_next("act_it")["id"] == "b")
	assert(not e.submit_vote("b", true)) # Actor cannot vote
	assert(e.submit_vote("a", true))
	assert(e.submit_vote("c", true))
	assert(not e.submit_vote("a", true)) # No double vote
	assert(e.resolve_round()["awards"]["b"] == 20)
	assert(e.draw_next("who_among_us")["id"] == "c")
	assert(not e.submit_vote("a", "a")) # No self-vote
	assert(e.submit_vote("a", "c"))
	assert(e.submit_vote("b", "c"))
	assert(e.resolve_round()["awards"]["c"] == 10)
	assert(e.draw_next("truth_or_fiction")["id"] == "d")
	assert(not e.submit_vote("b", false)) # Must commit truth first
	assert(not e.resolve_round().has("awards"))
	assert(not e.commit_story("b", true)) # Only actor may commit
	assert(e.commit_story("a", true))
	assert(not e.commit_story("a", false)) # Commitment immutable
	assert(e.submit_vote("b", false))
	assert(e.submit_vote("c", false))
	var result: Dictionary = e.resolve_round()
	assert(result["awards"]["a"] == 10) # Storyteller fooled majority
	var power_engine = Engine.new()
	var powers: Array[Dictionary] = [
		{"id": "qs_power_001", "category": "table_flip"},
		{"id": "qs_power_002", "category": "table_flip"}
	]
	assert(power_engine.setup(["a", "b", "c"], powers, 10, 99))
	assert(power_engine.draw_next("table_flip").size() > 0)
	if str(power_engine.current_card["id"]) == "qs_power_001":
		assert(power_engine.resolve_round().is_empty())
		assert(power_engine.apply_power("b").is_empty())
		assert(power_engine.apply_power("a").get("type") == "swap_next_turns")
		assert(power_engine.apply_power("a").is_empty())
		assert(power_engine.resolve_round()["power"]["type"] == "swap_next_turns")
		assert(power_engine.active_player_index == 2)
	else:
		assert(power_engine.apply_power("a").is_empty())
		assert(power_engine.resolve_round().is_empty())
	print("QAADET_EL_SOHAB_RULES_SMOKE_PASS")
	quit()
