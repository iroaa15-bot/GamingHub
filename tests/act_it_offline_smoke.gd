extends SceneTree
const PartyEngine = preload("res://scripts/qaadet_el_sohab_engine.gd")
const Game = preload("res://scripts/act_it_offline.gd")
func _initialize() -> void:
	var game = Game.new()
	var cards: Array[Dictionary] = game._load_cards()
	assert(cards.size() == 550)
	var seen := {}
	for card in cards:
		assert(str(card.get("category", "")) == "act_it")
		assert(int(card.get("duration_seconds", -1)) == 30)
		assert(int(card.get("points", -1)) == 20)
		assert(not str(card.get("text_ar", "")).strip_edges().is_empty())
		assert(not seen.has(card["id"]))
		seen[card["id"]] = true
	var engine = PartyEngine.new()
	assert(engine.setup(["a", "b", "c", "d"], cards, 20, 12))
	assert(engine.lock_category("act_it"))
	for i in range(20):
		assert(not engine.draw_next("act_it").is_empty())
		var actor: String = engine.players[engine.active_player_index]
		assert(not engine.submit_vote(actor, true))
		for player in engine.players:
			if player != actor:
				assert(engine.submit_vote(player, true))
		var result = engine.resolve_round()
		assert(result["awards"][actor] == 20)
	assert(engine.round_index == 20)
	assert(engine.scores["a"] == 100)
	assert(engine.scores["b"] == 100)
	assert(engine.scores["c"] == 100)
	assert(engine.scores["d"] == 100)
	print("ACT_IT_OFFLINE_SMOKE_PASS")
	quit()
