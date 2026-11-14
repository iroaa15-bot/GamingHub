extends RefCounted
static var _policy_cache: Dictionary={}
static var _arithmetic_regex: RegEx
## Bundled reviewed additions only; staging files are never loaded.
static func pictures() -> Dictionary:
 var path="res://data/approved_content/pictures.json"
 if not FileAccess.file_exists(path):return {}
 var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not value is Dictionary or value.get("approval",{}).get("kind")!="USER_ATTESTED_ORIGINAL_GENERATED_COMMERCIAL_USE":return {}
 return value
static func cards(original: Array) -> Array:
 var result=original.duplicate()
 var names: Dictionary={}
 for card in original:names[str(card.name)]=true
 var data: Dictionary=pictures()
 var by_name: Dictionary={}
 for item in data.get("catalog",[]):by_name[str(item.name)]=item
 for card in data.get("cards",[]):
  var item: Dictionary=by_name.get(str(card.get("name","")),{})
  var path: String=str(item.get("image",""))
  if names.has(str(card.get("name",""))) or not path.begins_with("res://assets/imported_photos/") or not ResourceLoader.exists(path):continue
  if not card.get("ar","") or not card.get("en","") or not card.get("tr",""):continue
  result.append(card);names[str(card.name)]=true
 return result
static func filters(original: Dictionary) -> Dictionary:
 var result: Dictionary=original.duplicate(true)
 var extra: Dictionary=pictures().get("filters",{})
 for key in ["categories","items"]:
  for name in extra.get(key,{}):
   if not result[key].has(name):result[key][name]=extra[key][name]
 return result
static func questions(original: Dictionary) -> Dictionary:
 var result: Dictionary=original.duplicate(true)
 var path="res://data/approved_content/questions.json"
 if not FileAccess.file_exists(path):return result
 var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not value is Dictionary:return result
 var ids: Dictionary={}
 for game in result:
  result[game]=result[game].filter(func(item):return question_allowed(item))
 for group in result.values():
  for item in group:ids[str(item.get("id",""))]=true
 for game in value.get("questions",{}):
  if not result.has(game):continue
  for item in value.questions[game]:
   if item.get("review",{}).get("status")!="VERIFIED_EDITORIAL" or ids.has(str(item.get("id",""))) or item.get("topic","") in ["math","numbers"]:continue
   var valid: bool=typeof(item.get("correct"))==TYPE_FLOAT or typeof(item.get("correct"))==TYPE_INT
   valid=valid and float(item.get("correct",-1))==float(int(item.get("correct",-1))) and int(item.get("correct",-1)) in range(4)
   for lang in ["ar","en","tr"]:
    var options: Array=item.get("choices_"+lang,[])
    var seen: Dictionary={}
    for choice in options:seen[str(choice).strip_edges().to_lower()]=true
    valid=valid and not str(item.get(lang,"")).is_empty() and options.size()==4 and seen.size()==4 and not seen.has("")
   if valid:result[game].append(item);ids[str(item.id)]=true
 return result
static func question_allowed(item: Dictionary) -> bool:
 if _policy_cache.is_empty():
  var path="res://data/approved_content/question_policy.json"
  if not FileAccess.file_exists(path):return true
  _policy_cache=JSON.parse_string(FileAccess.get_file_as_string(path))
  _arithmetic_regex=RegEx.new()
  if _arithmetic_regex.compile(str(_policy_cache.get("arithmetic_pattern","")))!=OK:return false
 if _policy_cache.get("excluded_ids",{}).has(str(item.get("id",""))) or _policy_cache.get("held_ids",{}).has(str(item.get("id",""))):return false
 return _arithmetic_regex!=null and _arithmetic_regex.search(str(item.get("ar","")))==null
