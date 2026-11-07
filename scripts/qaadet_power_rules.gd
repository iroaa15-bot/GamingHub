extends RefCounted
class_name QaadetPowerRules

# Deterministic, standalone power-card state. Integrate on authoritative server only.
const EFFECTS := ["swap_turn", "retry", "silence", "choose_category", "double_or_zero", "choose_two", "redraw", "speed_risk", "vote_category", "shield", "free_skip", "reverse"]
var pending: Dictionary = {}
var consumed: Dictionary = {}
var direction := 1

func activate(card_id: String, effect: String, actor: String, players: Array[String], target: String = "") -> Dictionary:
	if consumed.has(card_id) or not EFFECTS.has(effect) or not players.has(actor):
		return {"ok": false, "error": "invalid_or_used"}
	if effect == "swap_turn" or effect == "retry" or effect == "silence" or effect == "choose_two" or effect == "free_skip":
		if target == actor or not players.has(target):
			return {"ok": false, "error": "invalid_target"}
	consumed[card_id] = true
	var result := {"ok": true, "effect": effect, "actor": actor, "target": target}
	match effect:
		"reverse":
			direction *= -1
			result["direction"] = direction
		"shield", "double_or_zero", "speed_risk", "retry", "silence", "free_skip":
			var recipient := target if not target.is_empty() else actor
			pending[recipient] = {"effect": effect, "expires_after": 1}
		"swap_turn", "choose_two", "choose_category", "vote_category", "redraw":
			result["requires_validated_followup"] = true
	return result

func take_pending(player_id: String) -> Dictionary:
	var value: Dictionary = pending.get(player_id, {}).duplicate(true)
	pending.erase(player_id)
	return value

func next_player_index(index: int, player_count: int) -> int:
	if player_count <= 0:
		return -1
	return posmod(index + direction, player_count)
