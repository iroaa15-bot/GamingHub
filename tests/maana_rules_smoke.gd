extends SceneTree
const Rules = preload("res://scripts/maana_rules.gd")

func _initialize() -> void:
    assert(Rules.resolve({"a": 1, "b": 1, "c": 2}, ["a", "b", "c"])["penalty"] == "c")
    assert(Rules.resolve({"a": 1, "b": 2}, ["a", "b"])["status"] == "tie")
    assert(Rules.resolve({"a": 2, "b": 2}, ["a", "b"])["status"] == "unanimous")
    assert(Rules.resolve({"a": 1}, ["a", "b"])["status"] == "waiting")
    assert(Rules.resolve({"a": 1, "b": 2, "c": 2, "d": 1, "e": 2}, ["a", "b", "c", "d", "e"])["minority"].size() == 2)
    assert(Rules.resolve_reaction(["a", "b"], ["b", "a"])["player_id"] == "a")
    assert(Rules.apply_penalty({}, "a")["a"] == 1)
    assert(Rules.eliminated({"a": 7}, "a"))
    print("Maana rules smoke PASS")
    quit()
