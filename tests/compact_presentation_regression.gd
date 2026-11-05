extends SceneTree
const MenuSkin = preload("res://scripts/visual_skin.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var menu := VBoxContainer.new()
 root.add_child(menu)
 MenuSkin.compact_header(menu,"Gaming Hub")
 var action := Button.new()
 action.custom_minimum_size=Vector2(56,56)
 var fired := [0]
 action.pressed.connect(func(): fired[0]+=1)
 menu.add_child(action)
 MenuSkin.compact_menu(menu)
 MenuSkin.icon_action(action,"mic_off","Enable microphone")
 var valid := action.icon!=null and action.custom_minimum_size.y>=56 and action.tooltip_text=="Enable microphone"
 action.pressed.emit()
 valid = valid and fired[0]==1 and menu.get_node("CompactHeader").get_child(0).texture!=null
 for kind in ["back","settings","chat","list","mic","mic_off"]: valid=valid and MenuSkin.menu_icon(kind)!=null
 var main_script=load("res://scripts/main.gd")
 valid=valid and main_script!=null and main_script.can_instantiate()
 # Exercise only the changed presentation builders, without startup/network/save side effects.
 root.content_scale_size=Vector2i(420,900)
 root.size=Vector2i(420,900)
 var main=Control.new()
 root.add_child(main)
 main.set_script(main_script)
 main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 main.age_group="adult"
 main.reduced_motion=true
 main.show_home()
 valid=valid and main.root.has_node("CompactHeader")
 main.show_more_games()
 var grids=main.root.find_children("*","GridContainer",true,false)
 valid=valid and grids.size()==1 and grids[0].columns==3 and grids[0].get_child_count()==main.GAMES.size()
 main.reading_scale=1.5
 main.show_more_games()
 grids=main.root.find_children("*","GridContainer",true,false)
 valid=valid and grids[0].columns==1
 main.show_accessibility()
 grids=main.root.find_children("*","GridContainer",true,false)
 valid=valid and grids.size()==1 and grids[0].columns==2 and grids[0].get_child_count()==6
 main.queue_free()
 var room=load("res://scripts/photo_duel_extension_ui.gd").new()
 root.add_child(room)
 await process_frame
 valid=valid and room.yes_button.get_parent()==room.no_button.get_parent() and room.yes_button.get_parent() is HBoxContainer
 valid=valid and room.yes_button.get_signal_connection_list("pressed").size()==1 and room.no_button.get_signal_connection_list("pressed").size()==1
 valid=valid and not room._match_controls.visible and room.layout_direction==Control.LAYOUT_DIRECTION_RTL
 print("COMPACT_PRESENTATION_REGRESSION ",valid)
 room.queue_free()
 menu.queue_free()
 await process_frame
 quit(0 if valid else 1)
