extends SceneTree
var failures=[]
func _initialize() -> void:call_deferred("run")
func ck(ok: bool,name: String) -> void:
 print("APPROVED_CONTENT ",name," ",ok)
 if not ok:failures.append(name)
func run() -> void:
 var add=load("res://scripts/approved_content.gd")
 var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
 var cards: Array=add.cards(baseline.cards)
 ck(baseline.cards.size()==200 and cards.size()==228,"200 original plus 28 actual approved cards")
 var paths: Dictionary={}
 for item in add.pictures().get("catalog",[]):
  var texture: Texture2D=load(item.image)
  ck(texture!=null and texture.get_width()<=1024 and texture.get_height()<=1024,"actual decode "+str(item.id))
  paths[str(item.image)]=true
 ck(paths.size()==28,"unique actual assets")
 var filters=load("res://scripts/picture_filter_catalog.gd")
 var filtered: Dictionary=filters.definition()
 for item in add.pictures().cards:
  var record: Dictionary=filtered.items[item.name]
  ck(filters.select(cards,filtered,record.category,record.difficulty).any(func(c):return c.name==item.name),"selectable category and difficulty "+str(item.name))
 var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
 var bank: Dictionary=add.questions(raw)
 ck(bank["1"].size()==raw["1"].size()+1 and bank["5"].filter(func(q):return str(q.id).begins_with("GH-")).size()==7,"eight approved questions additive")
 var main=load("res://scripts/main.gd").new();root.add_child(main);await process_frame
 ck(main.CARDS.size()==228,"original main UI loads reviewed additions")
 for card in add.pictures().cards:
  ck(main.card_texture(card.name)!=null and main.matches_card_guess(card.ar,card) and main.matches_card_guess(card.en,card),"image labels and accepted answers "+str(card.name))
 main.queue_free();await process_frame
 print("APPROVED_CONTENT_RUNTIME ",failures.is_empty()," ",failures)
 quit(0 if failures.is_empty() else 1)
