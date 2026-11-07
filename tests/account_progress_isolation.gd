extends SceneTree
class Account:
 extends "res://scripts/network/gaminghub_auth.gd"
 var uploads:=0
 var fixture_dir: String="user://qa_account_isolation"
 func _ready() -> void:pass
 func _progress_file(name: String) -> String:return fixture_dir.path_join(name)
 func profile() -> Dictionary:return {"ok":true,"data":{"user":{"id":"account-b","local_progress":{"xp":4,"wins":1}}}}
 func sync_progress(_local: Dictionary) -> Dictionary:
  uploads+=1
  return {"ok":true}
func write(path: String,value: String) -> void:
 var file:=FileAccess.open(path,FileAccess.WRITE);assert(file!=null);file.store_string(value);file.close()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 create_timer(20).timeout.connect(func():push_error("Account isolation timeout");quit(1))
 root.get_node("PublishedContent").busy=true
 root.get_node("RoomAudioPolicy").set_music_enabled(false)
 root.get_node("RoomAudioPolicy").set_effects_enabled(false)
 var account:=Account.new();root.add_child(account)
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--fixture-dir="):account.fixture_dir=argument.trim_prefix("--fixture-dir=")
 assert(DirAccess.make_dir_recursive_absolute(account.fixture_dir)==OK)
 write(account._progress_file("progress_account_owner.txt"),"account-a")
 write(account._progress_file("progress_v10_all.json"),JSON.stringify({"xp":900,"wins":30,"language":"ar"}))
 await account.complete_player_sign_in({"xp":900,"wins":30})
 assert(account.uploads==0)
 var saved=JSON.parse_string(FileAccess.get_file_as_string(account._progress_file("progress_v10_all.json")))
 assert(saved.xp==4 and saved.wins==1 and saved.language=="ar")
 var backups=JSON.parse_string(FileAccess.get_file_as_string(account._progress_file("account_progress_backups.json")))
 assert(backups["account-a"].xp==900)
 assert(FileAccess.get_file_as_string(account._progress_file("progress_account_owner.txt"))=="account-b")
 await account.complete_player_sign_in({"xp":4,"wins":1})
 assert(account.uploads==1)
 account.queue_free();await process_frame
 print("ACCOUNT_PROGRESS_ISOLATION_PASS")
 quit(0)
