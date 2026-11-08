extends SceneTree
const Rules = preload("res://scripts/maana_rules.gd")

var failures := 0

func _check(ok: bool, label: String) -> void:
    if not ok:
        failures += 1
        push_error("FAIL: " + label)

func _initialize() -> void:
    _check(Rules.resolve({"a": 1, "b": 1, "c": 2}, ["a", "b", "c"]).get("penalty") == "c", "single minority")
    _check(Rules.resolve({"a": 1, "b": 2}, ["a", "b"]).get("status") == "invalid_players", "two players rejected")
    _check(Rules.resolve({"a": 2, "b": 2, "c": 2}, ["a", "b", "c"]).get("status") == "unanimous", "unanimous")
    _check(Rules.resolve({"a": 1}, ["a", "b", "c"]).get("status") == "waiting", "missing vote")
    _check(Rules.resolve({"a": 1, "b": 2, "c": 2, "d": 1, "e": 2}, ["a", "b", "c", "d", "e"]).get("minority", []).size() == 2, "two in minority")
    _check(Rules.resolve({"a": 1, "b": 1, "c": 2, "d": 2}, ["a", "b", "c", "d"]).get("status") == "tie", "even split")
    _check(Rules.resolve({"a": 1, "b": 3, "c": 2}, ["a", "b", "c"]).get("status") == "invalid_vote", "invalid choice")
    _check(Rules.resolve_reaction(["a", "b"], ["b", "a"]).get("player_id") == "a", "last reaction")
    _check(Rules.apply_penalty({}, "a").get("a") == 1, "penalty")
    _check(Rules.eliminated({"a": 7}, "a"), "elimination")
    if failures == 0:
        print("Maana rules smoke PASS (10 checks)")
        quit(0)
    else:
        print("Maana rules smoke FAIL: ", failures)
        quit(1)
