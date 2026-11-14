extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var main=Control.new()
 root.add_child(main)
 main.set_script(load("res://scripts/main.gd"))
 main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.age_group="18plus"
 main.sound_enabled=false
 main.reduced_motion=true
 main.show_home()
 var grid=main.root.get_node("UnifiedGameCatalog")
 var ids=[]
 for catalog in [grid,main.root.get_node("MoreOriginalGames")]:
  for tile in catalog.get_children():ids.append(tile.get_meta("game_id"))
 var valid=ids.size()==main.GAMES.size() and ids.count(0)==1
 for id in range(main.GAMES.size()): valid=valid and ids.count(id)==1
 var guess_buttons=0
 for control in main.root.find_children("*","Button",true,false):
  if control.text.contains("خمن صورتك"): guess_buttons+=1
 valid=valid and guess_buttons==1
 main.show_more_games()
 valid=valid and main.root.get_node("UnifiedGameCatalog").get_child_count()+main.root.get_node("MoreOriginalGames").get_child_count()==ids.size()
 for game in range(main.GAMES.size()):
  main.show_modes(game)
  var actions=[]
  for control in main.root.find_children("*","Button",true,false):
   if control.has_meta("mode_action"):actions.append(control.get_meta("mode_action"))
  valid=valid and actions.size()==3 and actions.has("friends") and actions.has("offline") and actions.has("games")
 print("UNIFIED_CATALOG_UI ",valid," — original catalog; exactly three game routes")
 main.queue_free()
 await process_frame
 quit(0 if valid else 1)
