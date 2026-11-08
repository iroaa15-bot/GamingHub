extends RefCounted
class_name MaanaRules

# Deterministic, server-authoritative round rules. Do not trust client timestamps.
const MIN_PLAYERS := 3
const MAX_PLAYERS := 6
const PENALTY_LIMIT := 7

static func resolve(votes: Dictionary, seated_ids: Array) -> Dictionary:
    if seated_ids.size() < MIN_PLAYERS or seated_ids.size() > MAX_PLAYERS:
        return {"status": "invalid_players"}
    if votes.size() != seated_ids.size():
        return {"status": "waiting"}
    var one: Array = []
    var two: Array = []
    for id in seated_ids:
        if not votes.has(id):
            return {"status": "waiting"}
        if typeof(votes[id]) != TYPE_INT or votes[id] not in [1, 2]:
            return {"status": "invalid_vote"}
        if votes[id] == 1:
            one.append(id)
        else:
            two.append(id)
    if one.size() == two.size():
        return {"status": "tie", "minority": [], "penalty": null}
    if one.is_empty() or two.is_empty():
        return {"status": "unanimous", "minority": [], "penalty": null}
    var minority: Array = one if one.size() < two.size() else two
    return {"status": "minority", "minority": minority, "penalty": minority[0] if minority.size() == 1 else null}

# Online replacement for physical hand stacking: eligible minority players
# tap once; server records receipt order. The LAST eligible player loses.
# A server deadline is required; missing taps rank after valid taps.
static func resolve_reaction(minority: Array, receipt_order: Array) -> Dictionary:
    if minority.is_empty():
        return {"status": "not_required"}
    if minority.size() == 1:
        return {"status": "penalty", "player_id": minority[0]}
    var seen: Dictionary = {}
    for id in receipt_order:
        if id in minority and not seen.has(id):
            seen[id] = true
    for id in minority:
        if not seen.has(id):
            return {"status": "penalty", "player_id": id}
    for i in range(receipt_order.size() - 1, -1, -1):
        if receipt_order[i] in minority:
            return {"status": "penalty", "player_id": receipt_order[i]}
    return {"status": "invalid"}

static func apply_penalty(penalties: Dictionary, player_id: Variant) -> Dictionary:
    var updated := penalties.duplicate(true)
    updated[player_id] = int(updated.get(player_id, 0)) + 1
    return updated

static func eliminated(penalties: Dictionary, player_id: Variant, limit: int = PENALTY_LIMIT) -> bool:
    return int(penalties.get(player_id, 0)) >= limit
