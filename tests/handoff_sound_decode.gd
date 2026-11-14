extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var folder="C:/Users/Omar/Documents/Codex/2026-10-24/referenced-chatgpt-conversation-this-is-an-3/outputs/master-integration-20261102/sound-decode"
 var results=[]
 var failed=false
 for name in DirAccess.get_files_at(folder):
  if not name.ends_with(".ogg"):continue
  var stream=AudioStreamOggVorbis.load_from_file(folder.path_join(name))
  var valid: bool=stream!=null and stream.get_length()>0
  failed=failed or not valid
  results.append({"file":name,"decoded":valid,"seconds":stream.get_length() if valid else 0,"auditioned":false,"approved":false})
 var report=FileAccess.open("C:/Users/Omar/Documents/GitHub/GamingHub/release/master_integration_20261102/sound_decode.json",FileAccess.WRITE)
 report.store_string(JSON.stringify(results,"  "));report.close()
 print("SOUND_ACTUAL_DECODE ",results.size()," ",not failed," NOT_AUDITIONED_NOT_APPROVED")
 quit(0 if results.size()==158 and not failed else 1)
