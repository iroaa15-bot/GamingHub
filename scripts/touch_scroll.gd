extends ScrollContainer
## Capture finger drags before descendant buttons; preserve their state and cancel taps.
var finger := -1
var origin := Vector2.ZERO
var previous := Vector2.ZERO
var dragging := false
var restore_buttons: Array[BaseButton] = []

func _input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed and finger == -1 and get_global_rect().has_point(event.position):
   # An editable drawing surface owns its single-finger strokes.
   if _drawing_at(self, event.position):
    return
   finger = event.index
   origin = event.position
   previous = event.position
  elif not event.pressed and event.index == finger:
   if dragging:
    get_viewport().set_input_as_handled()
    _restore.call_deferred()
   finger = -1
   dragging = false
 elif event is InputEventScreenDrag and event.index == finger:
  if not dragging and origin.distance_to(event.position) >= float(scroll_deadzone):
   dragging = true
   _disable_buttons(self)
  if dragging:
   scroll_vertical -= int(event.position.y - previous.y)
   get_viewport().set_input_as_handled()
  previous = event.position

func _drawing_at(node: Node, point: Vector2) -> bool:
 if node is Control and node.has_meta("drawing_input") and node.get_global_rect().has_point(point):
  return true
 for child in node.get_children():
  if _drawing_at(child, point):
   return true
 return false

func _disable_buttons(node: Node) -> void:
 for child in node.get_children():
  if child is BaseButton and not child.disabled:
   child.disabled = true
   restore_buttons.append(child)
  _disable_buttons(child)

func _restore() -> void:
 for button in restore_buttons:
  if is_instance_valid(button):
   button.disabled = false
 restore_buttons.clear()
