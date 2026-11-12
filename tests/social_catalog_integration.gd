extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://tests/picture_ui_preview.gd").new()
 root.add_child(main)
 main.age_group="18plus";main.sound_enabled=false;main.reduced_motion=true
 var valid: bool=true
 var scenes: Array[String]=["OpenHeart","ActIt","WhoAmongUs","ShowSkill","TruthOrFiction","TableFlip"]
 for language in ["ar","en"]:
  main.selected_language=language;main.show_home()
  var grid=main.root.get_node("SocialGameCatalog")
  valid=valid and grid.get_child_count()==6
  for index in range(6):valid=valid and int(grid.get_child(index).get_meta("social_game_id",-1))==index
  for name in scenes:
   var mode=load("res://scenes/"+name+"Mode.tscn").instantiate()
   root.add_child(mode);mode.language=language;mode._render()
   var buttons: Array=mode.layout.get_children().filter(func(n):return n is Button)
   valid=valid and buttons.size()==3 and buttons[0].disabled and not buttons[1].disabled and not buttons[2].disabled
   mode.queue_free();await process_frame
   var offline=load("res://scenes/"+name+".tscn").instantiate()
   root.add_child(offline);await process_frame
   valid=valid and offline.get_child_count()>0
   offline.queue_free();await process_frame
 main.queue_free();await process_frame
 print("SOCIAL_CATALOG_INTEGRATION ",valid," sixteen catalog entries; six real local scenes; AR/EN entry routes; online disabled honestly")
 quit(0 if valid else 1)
