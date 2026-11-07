extends SceneTree
const Engine = preload("res://scripts/qaadet_el_sohab_engine.gd")

func _initialize() -> void:
	var e = Engine.new()
	var cards: Array[Dictionary] = [
		{"id": "vote", "category": "who_among_us"},
		{"id": "truth", "category": "truth_or_fiction"}
	]
	assert(e.setup(["a", "b", "c"], cards, 10, 13))
	assert(e.draw_next("who_among_us")["id"] == "vote")
	assert(not e.submit_vote("a", "b")) # Active storyteller cannot vote
	assert(not e.submit_vote("b", "b")) # Self vote
	assert(e.submit_vote("b", "a"))
	assert(not e.submit_vote("b", "c")) # Duplicate
	assert(e.submit_vote("c", "a"))
	var outcome: Dictionary = e.resolve_round()
	assert(outcome["awards"].get("a", 0) == 10)
	assert(e.draw_next("truth_or_fiction")["id"] == "truth")
	assert(e.submit_vote("a", true))
	assert(e.submit_vote("c", false))
	outcome = e.resolve_round(true)
	assert(outcome["awards"].get("a", 0) == 10)
	assert(outcome["awards"].get("b", 0) == 0)
	print("QAADET_LOCAL_VOTING_SMOKE_PASS")
	quit()
