extends SceneTree
## Godot 4.5 headless regression tests for core offline social rules.
const Engine = preload("res://scripts/qaadet_el_sohab_engine.gd")
func _card(category: String, id: String) -> Dictionary:
	return {"id": id, "category": category, "text_ar": "اختبار قواعد اللعبة", "points": 10}
func _engine(category: String, players: Array[String]) -> RefCounted:
	var engine = Engine.new()
	var cards: Array[Dictionary] = []
	for i in range(25):
		cards.append(_card(category, category + str(i)))
	assert(engine.setup(players, cards, 10, 42))
	assert(engine.lock_category(category))
	assert(not engine.draw_next(category).is_empty())
	return engine
func _initialize() -> void:
	_test_open_heart()
	_test_majority()
	_test_who_among_us()
	_test_truth()
	_test_guards()
	print("SOCIAL_RULES_REGRESSION_PASS")
	quit()
func _test_open_heart() -> void:
	var e = _engine("open_heart", ["a", "b"])
	assert(e.resolve_round(false)["awards"].is_empty())
	assert(not e.draw_next("open_heart").is_empty())
	assert(e.resolve_round(true)["awards"]["b"] == 10)
func _test_majority() -> void:
	for category in ["act_it", "show_skill"]:
		var e = _engine(category, ["a", "b", "c", "d"])
		assert(not e.submit_vote("a", true))
		assert(e.submit_vote("b", true))
		assert(not e.submit_vote("b", true))
		assert(e.submit_vote("c", true))
		assert(e.submit_vote("d", false))
		assert(e.resolve_round()["awards"]["a"] == 20)
		assert(not e.draw_next(category).is_empty())
		assert(e.submit_vote("a", true))
		assert(e.submit_vote("c", true))
		assert(e.submit_vote("d", false))
		assert(e.resolve_round()["awards"].is_empty())
func _test_who_among_us() -> void:
	var e = _engine("who_among_us", ["a", "b", "c", "d"])
	assert(not e.submit_vote("b", "b"))
	assert(e.submit_vote("b", "c"))
	assert(e.submit_vote("c", "b"))
	assert(e.submit_vote("d", "c"))
	assert(e.resolve_round()["awards"]["c"] == 10)
	assert(not e.draw_next("who_among_us").is_empty())
	assert(e.submit_vote("a", "c"))
	assert(e.submit_vote("c", "a"))
	assert(e.submit_vote("d", "a"))
	assert(e.resolve_round()["awards"]["a"] == 10)
func _test_truth() -> void:
	var e = _engine("truth_or_fiction", ["a", "b", "c", "d"])
	assert(not e.submit_vote("b", true))
	assert(not e.commit_story("b", true))
	assert(e.commit_story("a", false))
	assert(not e.commit_story("a", true))
	assert(e.submit_vote("b", true))
	assert(e.submit_vote("c", true))
	assert(e.submit_vote("d", false))
	var result = e.resolve_round()
	assert(result["awards"]["a"] == 10)
	assert(result["awards"]["d"] == 10)
func _test_guards() -> void:
	var e = Engine.new()
	var cards: Array[Dictionary] = [_card("open_heart", "x")]
	assert(not e.setup(["a"], cards))
	assert(not e.setup(["a", "a"], cards))
	assert(e.setup(["a", "b"], cards, 10, 17))
	assert(not e.lock_category("invalid"))
	assert(e.lock_category("open_heart"))
	assert(e.draw_next("act_it").is_empty())
