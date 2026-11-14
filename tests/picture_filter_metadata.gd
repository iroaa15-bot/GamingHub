extends SceneTree
const Filters=preload("res://scripts/picture_filter_catalog.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var cards: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json")).cards
 var data=Filters.definition()
 var valid=cards.size()==data.items.size() and data.items.size()==200
 for card in cards:
  var item: Dictionary=data.items.get(card.name,{})
  valid=valid and data.categories.has(item.get("category","")) and item.get("difficulty","") in ["easy","medium","hard"]
 for key in data.categories:
  for lang in ["ar","en","tr"]: valid=valid and not str(data.categories[key].get(lang,"")).is_empty()
  for rank in ["all","easy","medium","hard"]:
   var filtered=Filters.select(cards,data,key,rank)
   var names=[]
   for card in filtered:
    valid=valid and data.items[card.name].category==key and (rank=="all" or data.items[card.name].difficulty==rank) and card.name not in names
    names.append(card.name)
 valid=valid and Filters.select(cards,data,"fruits","all").size()==27 and Filters.select(cards,data,"animals","all").size()==55
 var main=Control.new();root.add_child(main);main.set_script(load("res://scripts/main.gd"));main.sound_enabled=false;main.game=0;main.load_catalog();main.picture_category="fruits";main.picture_guess_difficulty="hard"
 valid=valid and main.deck_cards().size()>=2
 main.show_decks()
 valid=valid and not main.root.find_children("*","Button",true,false).is_empty()
 main.game=8;main.deck="Animal"
 valid=valid and main.deck_cards().size()==55
 print("PICTURE_FILTER_METADATA ",valid," — classification/filtering only; no image regeneration or old asset tests")
 main.queue_free();await process_frame
 quit(0 if valid else 1)
