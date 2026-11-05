extends Button
signal move_requested(source: int,target: int)
var item_index := 0
var group_key := ""
var ordering_enabled := false

func _get_drag_data(_position: Vector2) -> Variant:
 if disabled or not ordering_enabled:return null
 var preview:=Label.new();preview.text=text;preview.add_theme_font_size_override("font_size",18)
 set_drag_preview(preview)
 return {"kind":"gaminghub_order","source":item_index,"group":group_key,"list":get_parent().get_instance_id()}

func _can_drop_data(_position: Vector2,data: Variant) -> bool:
 return ordering_enabled and not disabled and data is Dictionary and data.get("kind")=="gaminghub_order" and data.get("group")==group_key and data.get("list")==get_parent().get_instance_id() and typeof(data.get("source"))==TYPE_INT

func _drop_data(position: Vector2,data: Variant) -> void:
 if _can_drop_data(position,data):move_requested.emit(int(data.source),item_index)
