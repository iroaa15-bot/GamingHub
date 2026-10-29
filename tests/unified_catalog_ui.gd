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
 main.show_modes(0)
 var daily=0
 for control in main.root.find_children("*","Button",true,false):
  if control.text=="ألغاز الصور اليومية": daily+=1
 valid=valid and daily==1
 main.show_modes(5)
 var championship=0
 for control in main.root.find_children("*","Button",true,false):
  if control.text.contains("بطولة الأبطال"): championship+=1
 valid=valid and championship==1
 print("UNIFIED_CATALOG_UI ",valid," — each original game once; mode routes preserved; no backend/old tests rerun")
 main.queue_free()
 await process_frame
 quit(0 if valid else 1)
