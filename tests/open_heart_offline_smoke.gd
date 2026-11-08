extends SceneTree
const Engine = preload("res://scripts/qaadet_el_sohab_engine.gd")
const OpenHeart = preload("res://scripts/open_heart_offline.gd")

func _initialize() -> void:
	var game = OpenHeart.new()
	var cards: Array[Dictionary] = game._load_cards()
	assert(cards.size() >= 20)
	var ids := {}
	for card in cards:
		assert(card["category"] == "open_heart")
		assert(not ids.has(card["id"]))
		ids[card["id"]] = true
	var engine = Engine.new()
	assert(engine.setup(["Ali", "Mona"], cards, 20, 1234))
	assert(engine.lock_category("open_heart"))
	assert(engine.draw_next("act_it").is_empty())
	for i in range(20):
		var card = engine.draw_next("open_heart")
		assert(not card.is_empty())
		var result = engine.resolve_round(i % 2 == 0)
		assert(not result.is_empty())
	assert(engine.round_index == 20)
	assert(engine.scores["Ali"] == 100)
	assert(engine.scores["Mona"] == 0)
	assert(engine.draw_next("open_heart").is_empty())
	print("OPEN_HEART_OFFLINE_SMOKE_PASS")
	quit()
