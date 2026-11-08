extends RefCounted
class_name QaadetElSohabEngine

# Standalone rules prototype. Server must validate authoritative actions in online play.
const MIN_PLAYERS := 2
const MAX_PLAYERS := 6
const VALID_ROUNDS := [10, 15, 20]
const CATEGORIES := ["open_heart", "act_it", "who_among_us", "show_skill", "truth_or_fiction", "table_flip"]
var players: Array[String] = []
var scores: Dictionary = {}
var deck: Array[Dictionary] = []
var used_ids: Dictionary = {}
var current_card: Dictionary = {}
var round_index := 0
var round_limit := 10
var active_player_index := 0
var votes: Dictionary = {}
var resolved := false
var story_committed := false
var committed_story_truth := false
var rng := RandomNumberGenerator.new()

func setup(player_ids: Array[String], cards: Array[Dictionary], rounds: int = 10, seed_value: int = 0) -> bool:
	if player_ids.size() < MIN_PLAYERS or player_ids.size() > MAX_PLAYERS or not VALID_ROUNDS.has(rounds):
		return false
	if player_ids.size() != _unique_count(player_ids):
		return false
	players = player_ids.duplicate()
	scores.clear()
	used_ids.clear()
	for id in players:
		scores[id] = 0
	deck.clear()
	var seen_card_ids := {}
	for card in cards:
		if not card.has("id") or not card.has("category") or not CATEGORIES.has(str(card["category"])):
			continue
		if str(card["id"]).is_empty() or seen_card_ids.has(str(card["id"])):
			continue
		seen_card_ids[str(card["id"])] = true
		deck.append(card.duplicate(true))
	round_limit = rounds
	round_index = 0
	active_player_index = 0
	current_card.clear()
	votes.clear()
	resolved = false
	story_committed = false
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	return not deck.is_empty()

func _unique_count(items: Array[String]) -> int:
	var seen := {}
	for item in items:
		seen[item] = true
	return seen.size()

func draw_next(category: String = "") -> Dictionary:
	if round_index >= round_limit or not current_card.is_empty() and not resolved:
		return {}
	var available: Array[Dictionary] = []
	for card in deck:
		if not used_ids.has(card["id"]) and (category.is_empty() or str(card["category"]) == category):
			available.append(card)
	if available.is_empty():
		return {}
	current_card = available[rng.randi_range(0, available.size() - 1)].duplicate(true)
	used_ids[current_card["id"]] = true
	votes.clear()
	resolved = false
	story_committed = false
	return current_card.duplicate(true)

func commit_story(actor: String, is_true: bool) -> bool:
	if current_card.is_empty() or resolved or story_committed or str(current_card.get("category", "")) != "truth_or_fiction":
		return false
	if actor != players[active_player_index]:
		return false
	committed_story_truth = is_true
	story_committed = true
	return true

func submit_vote(voter: String, choice: Variant) -> bool:
	if current_card.is_empty() or resolved or not players.has(voter):
		return false
	var category := str(current_card["category"])
	var actor := players[active_player_index]
	if category == "open_heart" or category == "table_flip" or voter == actor or votes.has(voter):
		return false
	if category == "who_among_us":
		if not choice is String or not players.has(choice) or choice == voter:
			return false
	elif category == "act_it" or category == "show_skill" or category == "truth_or_fiction":
		if not choice is bool:
			return false
		if category == "truth_or_fiction" and not story_committed:
			return false
	else:
		return false
	votes[voter] = choice
	return true

func resolve_round(story_is_true: bool = false, participated: bool = true) -> Dictionary:
	if current_card.is_empty() or resolved:
		return {}
	var category := str(current_card["category"])
	if category == "truth_or_fiction" and not story_committed:
		return {}
	var actor := players[active_player_index]
	var award := {}
	if category == "open_heart":
		if participated:
			_award(actor, 10, award)
	elif category == "act_it" or category == "show_skill":
		var approvals := 0
		var rejects := 0
		for value in votes.values():
			if value == true:
				approvals += 1
			else:
				rejects += 1
		if approvals > rejects and approvals > 0:
			_award(actor, 20, award)
	elif category == "who_among_us":
		var counts := {}
		for target in votes.values():
			counts[target] = counts.get(target, 0) + 1
		var top := 0
		var winners: Array = []
		for target in counts:
			if counts[target] > top:
				top = counts[target]
				winners = [target]
			elif counts[target] == top:
				winners.append(target)
		if winners.size() == 1:
			_award(str(winners[0]), 10, award)
	elif category == "truth_or_fiction":
		var correct := 0
		var wrong := 0
		for voter in votes:
			if votes[voter] == committed_story_truth:
				_award(voter, 10, award)
				correct += 1
			else:
				wrong += 1
		if wrong > correct:
			_award(actor, 10, award)
	# Power effects need dedicated validated server commands; no fake application.
	resolved = true
	round_index += 1
	active_player_index = (active_player_index + 1) % players.size()
	var result := {"awards": award, "scores": scores.duplicate(), "round": round_index, "finished": round_index >= round_limit}
	current_card.clear()
	story_committed = false
	return result

func _award(player_id: String, amount: int, awards: Dictionary) -> void:
	scores[player_id] = int(scores[player_id]) + amount
	awards[player_id] = awards.get(player_id, 0) + amount
