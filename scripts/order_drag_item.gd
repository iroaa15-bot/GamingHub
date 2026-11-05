extends Button
signal move_requested(source: int,target: int)
var item_index := 0
var group_key := ""
var ordering_enabled := false
var _touch_index := -1
var _touch_origin := Vector2.ZERO
var _touch_moved := false
var _rest_modulate := Color.WHITE

# Consume an item gesture before ScrollContainer can turn it into page scrolling.
# Desktop keeps Godot's normal drag-and-drop path below.
func _input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed:
   if _touch_index!=-1 or disabled or not ordering_enabled or not _contains_touch(event.position):return
   _touch_index=event.index;_touch_origin=event.position;_touch_moved=false
   _rest_modulate=self_modulate;self_modulate=Color(1,1,0.6)
   get_viewport().set_input_as_handled()
  elif event.index==_touch_index:
   get_viewport().set_input_as_handled()
   var target: Control=null
   if not event.canceled and _touch_moved and ordering_enabled and not disabled:
    for sibling in get_parent().get_children():
     if sibling!=self and sibling.get_script()==get_script() and sibling.group_key==group_key and sibling.ordering_enabled and not sibling.disabled and sibling._contains_touch(event.position):
      target=sibling;break
   _touch_index=-1;self_modulate=_rest_modulate
   if target!=null:move_requested.emit(item_index,target.item_index)
 elif event is InputEventScreenDrag and event.index==_touch_index:
  _touch_moved=_touch_moved or event.position.distance_to(_touch_origin)>12.0
  get_viewport().set_input_as_handled()

func _contains_touch(point: Vector2) -> bool:
 if not is_visible_in_tree():return false
 var control: Node=self
 while control is Control:
  if control==self or control.clip_contents:
   var local_point: Vector2=control.get_global_transform_with_canvas().affine_inverse()*point
   if not Rect2(Vector2.ZERO,control.size).has_point(local_point):return false
  control=control.get_parent()
 return true

func _get_drag_data(_position: Vector2) -> Variant:
 if disabled or not ordering_enabled:return null
 var preview:=Label.new();preview.text=text;preview.add_theme_font_size_override("font_size",18)
 set_drag_preview(preview)
 return {"kind":"gaminghub_order","source":item_index,"group":group_key,"list":get_parent().get_instance_id()}

func _can_drop_data(_position: Vector2,data: Variant) -> bool:
 return ordering_enabled and not disabled and data is Dictionary and data.get("kind")=="gaminghub_order" and data.get("group")==group_key and data.get("list")==get_parent().get_instance_id() and typeof(data.get("source"))==TYPE_INT

func _drop_data(position: Vector2,data: Variant) -> void:
 if _can_drop_data(position,data):move_requested.emit(int(data.source),item_index)
