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
	assert(e.submit_vote("a", false))
	assert(e.submit_vote("b", false))
	var result: Dictionary = e.resolve_round(true)
	assert(result["awards"]["c"] == 10) # Storyteller fooled majority
	print("QAADET_EL_SOHAB_RULES_SMOKE_PASS")
	quit()
