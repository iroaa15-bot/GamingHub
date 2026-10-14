extends SceneTree

class FakeEarnedAdapter extends Node:
 signal earned_reward(request_id: int, reward_type: String, amount: int)
 func show_rewarded(_request_id: int) -> void:
  pass

var count: int = 0
func _initialize() -> void:
 call_deferred("check_release")

func check_release() -> void:
 var manager = load("res://scripts/ad_manager.gd").new()
 root.add_child(manager)
 var adapter := FakeEarnedAdapter.new()
 root.add_child(adapter)
 assert(manager.attach_native_plugin(adapter))
 manager.configuration["mode"] = "android_test_sdk"
 manager.set_audience("children")
 manager.update_consent(true, true)
 manager.register_native_adapter(true, true)
 assert(not manager.is_ad_eligible())
 manager.set_audience("adults")
 assert(not manager.is_ad_eligible())
 manager.update_consent(true, true)
 manager.register_native_adapter(true, true)
 manager.reward_earned.connect(func(_currency: String, amount: int) -> void:
  assert(amount == 50)
  count += 1)
 manager.request_rewarded_ad()
 var first: int = manager.pending_request_id
 assert(first > 0 and count == 0)
 adapter.earned_reward.emit(first + 1, "Coins", 50)
 adapter.earned_reward.emit(first, "Coins", 49)
 assert(count == 0)
 adapter.earned_reward.emit(first, "Coins", 50)
 adapter.earned_reward.emit(first, "Coins", 50)
 assert(count == 1)
 manager.request_rewarded_ad()
 var second: int = manager.pending_request_id
 manager.report_rewarded_failed(second, "closed without earned reward")
 adapter.earned_reward.emit(second, "Coins", 50)
 assert(count == 1)
 manager.set_audience("children")
 assert(not manager.is_ad_eligible())
 var library = load("res://scripts/daily_rounds.gd").new()
 var fixtures: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/history_fixture.json"))
 library._merge([fixtures[0]], false)
 library._merge([fixtures[1]], false)
 library._merge([fixtures[1]], false)
 assert(library.history.size() == 2)
 assert(library.history[0]["date_utc"] > library.history[1]["date_utc"])
 assert(library.total_questions() == 48)
 library.free()
 adapter.queue_free()
 manager.queue_free()
 print("RELEASE_RUNTIME_PASS: newest-first additive merge, deduplication, age/consent gates, exact 50 Coins, duplicate/wrong/stale/close callback rejection; simulated adapter, not SDK device evidence")
 quit(0)
