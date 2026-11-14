extends SceneTree
const MenuSkin = preload("res://scripts/visual_skin.gd")
class DragPreview extends TextureRect:
 func _get_drag_data(_at: Vector2) -> Variant: return {"drag":true}
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var box=VBoxContainer.new()
 var text=Label.new()
 var image=TextureRect.new()
 var button=Button.new()
 var field=LineEdit.new()
 var custom=DragPreview.new()
 var handled=TextureRect.new()
 handled.gui_input.connect(func(_event: InputEvent): pass)
 for node in [text,image,button,field,custom,handled]: box.add_child(node)
 var original_filters := [field.mouse_filter,custom.mouse_filter,handled.mouse_filter]
 MenuSkin.enable_menu_swipe(box)
 var native_scroll: bool=text.mouse_filter==Control.MOUSE_FILTER_IGNORE and image.mouse_filter==Control.MOUSE_FILTER_IGNORE and button.mouse_filter==Control.MOUSE_FILTER_PASS
 var protected: bool=[field.mouse_filter,custom.mouse_filter,handled.mouse_filter]==original_filters
 var ui=load("res://scripts/photo_duel_extension_ui.gd").new()
 root.add_child(ui)
 var lobby: bool=ui._lobby_controls.visible and not ui._match_controls.visible and ui._scores.text=="" and ui.heading.text.find("0/0")==-1
 var defaults: bool=ui.players_field.get_selected_id()==2 and ui.timer_field.get_selected_id()==30 and int(ui.target_field.value)==10
 var buttons: bool=is_instance_valid(ui.guess_button) and is_instance_valid(ui.yes_button) and is_instance_valid(ui.correct_button) and ui.presets.size()==8
 print("MOBILE_ROOM_LAYOUT_REGRESSION ",native_scroll," ",protected," ",lobby," ",defaults," ",buttons)
 ui.free()
 box.free()
 quit(0 if native_scroll and protected and lobby and defaults and buttons else 1)
