extends RefCounted
const FILE := "user://player_preferences_v1.json"
const PROGRESS := "user://progress_v10_all.json"

static func language() -> String:
 for path in [FILE,PROGRESS]:
  if not FileAccess.file_exists(path):continue
  var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
  if value is Dictionary and str(value.get("language","")) in ["ar","en"]:return str(value.language)
 return "ar"

static func save_language(value: String) -> void:
 if value not in ["ar","en"]:return
 var file:=FileAccess.open(FILE,FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify({"language":value}));file.close()
 var progress: Variant=JSON.parse_string(FileAccess.get_file_as_string(PROGRESS)) if FileAccess.file_exists(PROGRESS) else {}
 if not progress is Dictionary:progress={}
 progress.language=value
 file=FileAccess.open(PROGRESS,FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify(progress));file.close()
