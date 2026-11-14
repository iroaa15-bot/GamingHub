extends SceneTree
## Godot 4.5 headless regression tests for core offline social rules.
const PartyEngine = preload("res://scripts/qaadet_el_sohab_engine.gd")
func _card(category: String, id: String) -> Dictionary:
	return {"id": id, "category": category, "text_ar": "اختبار قواعد اللعبة " + id, "points": 10}
func _engine(category: String, players: Array[String]) -> QaadetElSohabEngine:
	var engine = PartyEngine.new()
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
	_test_swap_turn_order()
	_test_category_and_choice_guards()
	_test_duplicate_prompts()
	print("SOCIAL_RULES_REGRESSION_PASS")
	quit()
func _test_open_heart() -> void:
	var e = _engine("open_heart", ["a", "b"])
	assert(e.resolve_round(false)["awards"].is_empty())
	assert(not e.draw_next("open_heart").is_empty())
	assert(e.resolve_round(true)["awards"]["b"] == 10)

func _test_duplicate_prompts() -> void:
	var e=PartyEngine.new()
	var cards: Array[Dictionary]=[
		{"id":"first","category":"open_heart","text_ar":"إيه أجمل ذكرى؟"},
		{"id":"second","category":"open_heart","text_ar":"ايه اجمل ذكرى!"}]
	assert(e.setup(["a","b"],cards,10,42))
	assert(e.deck.size()==1)
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
		assert(e.resolve_round()["awards"]["b"] == 20)
func _test_who_among_us() -> void:
	var e = _engine("who_among_us", ["a", "b", "c", "d"])
	assert(not e.submit_vote("b", "b"))
	assert(e.submit_vote("a", "c"))
	assert(e.submit_vote("b", "c"))
	assert(e.submit_vote("c", "b"))
	assert(e.submit_vote("d", "c"))
	assert(e.resolve_round()["awards"]["c"] == 10)
	assert(not e.draw_next("who_among_us").is_empty())
	assert(e.submit_vote("a", "c"))
	assert(e.submit_vote("b", "a"))
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
func _test_category_and_choice_guards() -> void:
	var e = PartyEngine.new()
	var cards: Array[Dictionary] = []
	for i in range(25):
		cards.append(_card("open_heart", "guard_" + str(i)))
	assert(e.setup(["a", "b"], cards, 10, 123))
	assert(e.draw_next("open_heart").is_empty())
	assert(e.lock_category("open_heart"))
	e.next_card_choice = 2
	assert(e.draw_next("open_heart").is_empty())
	var offers := e.available_card_choices("open_heart")
	assert(offers.size() == 2)
	assert(e.available_card_choices("open_heart") == offers)
	assert(e.draw_chosen_card("open_heart", "nonexistent").is_empty())
	assert(not e.draw_chosen_card("open_heart", str(offers[0]["id"])).is_empty())
	assert(e.resolve_round(true)["round"] == 1)

func _test_swap_turn_order() -> void:
	var e = PartyEngine.new()
	var cards: Array[Dictionary] = [_card("table_flip", "qs_power_001")]
	for i in range(24):
		cards.append(_card("table_flip", "qs_power_" + str(100 + i)))
	assert(e.setup(["a", "b", "c", "d"], cards, 10, 17))
	assert(e.lock_category("table_flip"))
	# Use a deterministic direct card selection for this turn-order test.
	e.current_card = cards[0].duplicate(true)
	assert(not e.apply_power("a").is_empty())
	assert(not e.resolve_round().is_empty())
	assert(e.players[e.active_player_index] == "c")
	for expected in ["b", "d"]:
		e.current_card = _card("open_heart", "turn_" + expected)
		e.resolved = false
		assert(not e.resolve_round(true).is_empty())
		assert(e.players[e.active_player_index] == expected)

func _test_guards() -> void:
	var e = PartyEngine.new()
	var cards: Array[Dictionary] = [_card("open_heart", "x")]
	assert(not e.setup(["a"], cards))
	assert(not e.setup(["a", "a"], cards))
	assert(e.setup(["a", "b"], cards, 10, 17))
	assert(not e.lock_category("invalid"))
	assert(e.lock_category("open_heart"))
	assert(e.draw_next("act_it").is_empty())
