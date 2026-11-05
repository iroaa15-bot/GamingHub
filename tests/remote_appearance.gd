extends SceneTree
func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var content = root.get_node("PublishedContent")
 content.busy=true
 var settings: Dictionary={"background":"#030a28","background_end":"#121044","primary":"#0c1d51","font_scale":1.25,"home_columns":1,"primary_count":6,"game_order":[6,3,0,1,2,4,5,7,8,9],"enabled_games":[3,6],"title_ar":"عنوان مخصص","title_en":"Custom menu","notice_ar":"رسالة","notice_en":"Notice","show_activities":false,"custom_primary":false}
 assert(content._accept_settings({"schema":1,"version":7,"settings":settings}))
 assert(content.catalog_order()==[6,3])
 var main=load("res://scenes/Main.tscn").instantiate()
 root.add_child(main)
 await process_frame
 main.age_group="all"
 main.show_home()
 var grid=main.root.find_child("UnifiedGameCatalog",true,false)
 assert(grid!=null and grid.columns==1 and grid.get_child_count()==2)
 assert(grid.get_child(0).get_meta("game_id")==6)
 assert(content.settings_version==7)
 var invalid: Dictionary=settings.duplicate(true)
 invalid.enabled_games=[]
 assert(not content._accept_settings({"schema":1,"version":8,"settings":invalid}))
 assert(content.catalog_order().size()==10 and content.settings.is_empty())
 main.show_home()
 grid=main.root.find_child("UnifiedGameCatalog",true,false)
 assert(grid.get_child_count()==6)
 invalid=settings.duplicate(true);invalid.primary="#ffffff"
 assert(not content._accept_settings({"schema":1,"version":9,"settings":invalid}))
 assert(not content._accept_settings(null))
 main.queue_free()
 await process_frame
 print("REMOTE_APPEARANCE_PASS: validated menu order, visibility, layout, and safe local fallback")
 quit()
