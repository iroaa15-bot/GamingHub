extends RefCounted
## Original picture metadata only; assets, answer aliases and question facts are unchanged.
static func definition() -> Dictionary:
 var value: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/picture_filters.json"))
 return load("res://scripts/approved_content.gd").filters(value) if value is Dictionary else {}
static func select(cards: Array, data: Dictionary, category: String, difficulty: String) -> Array:
 var result: Array=[]
 var items: Dictionary=data.get("items",{})
 for card in cards:
  var item: Dictionary=items.get(str(card.get("name","")),{})
  if category!="all" and item.get("category","")!=category: continue
  if difficulty!="all" and item.get("difficulty","")!=difficulty: continue
  result.append(card)
 return result
