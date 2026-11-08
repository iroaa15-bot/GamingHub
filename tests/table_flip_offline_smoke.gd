extends SceneTree
const Game = preload("res://scripts/table_flip_offline.gd")
func _initialize() -> void:
	var game = Game.new()
	var cards: Array[Dictionary] = game._load_cards()
	assert(cards.size() == 300)
	var ids := {}
	var types := {}
	for card in cards:
		assert(card["category"] == "table_flip")
		assert(not str(card.get("text_ar", "")).is_empty())
		assert(not ids.has(card["id"]))
		ids[card["id"]] = true
		var kind := str(card.get("power_type", ""))
		if not kind.is_empty():
			types[kind] = true
	assert(types.size() == 10)
	assert(game.LEGACY.size() == 22)
	print("TABLE_FLIP_300_CARD_INTEGRITY_PASS")
	quit()
