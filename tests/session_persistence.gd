extends SceneTree
class Store:
 extends RefCounted
 var saved := ""
 func storeSession(value: String) -> bool:
  saved = value
  return true
 func loadSession() -> String: return saved
 func clearSession() -> bool:
  saved = ""
  return true
class Account:
 extends "res://scripts/network/gaminghub_auth.gd"
 var reply: Dictionary = {}
 func _ready() -> void: pass
 func _call(_endpoint: String, _method: int, _data: Dictionary = {}) -> Dictionary:
  return reply
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var storage := Store.new()
 var auth := Account.new()
 root.add_child(auth)
 auth.secure_store = storage
 assert(auth.configure("https://identity.example.test"))
 auth._accept_session({"access_token":"memory-only-access", "refresh_token":"protected-refresh"})
 assert(not storage.saved.contains("memory-only-access"))
 var saved: Dictionary = JSON.parse_string(storage.saved)
 assert(saved.keys().size()==2 and saved.refresh_token=="protected-refresh")
 auth.access_token = ""
 auth.reply={"ok":false,"status":0}
 await auth._restore_session()
 assert(auth.refresh_token=="protected-refresh" and not storage.saved.is_empty())
 auth.reply={"ok":true,"status":200,"data":{"access_token":"renewed-access","refresh_token":"rotated-refresh"}}
 await auth._restore_session()
 assert(auth.access_token=="renewed-access" and storage.saved.contains("rotated-refresh"))
 auth.reply={"ok":false,"status":401}
 await auth.refresh_session()
 assert(auth.access_token.is_empty() and storage.saved.is_empty())
 auth._accept_session({"access_token":"new-access","refresh_token":"new-refresh"})
 assert(auth.configure("https://different.example.test"))
 assert(auth.access_token.is_empty() and storage.saved.is_empty())
 auth.queue_free()
 print("PASS: refresh restoration, rotation, offline retention, invalidation, origin isolation; storage mock, not Android Keystore hardware test")
 quit()
