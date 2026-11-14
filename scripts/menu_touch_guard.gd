extends Node
## Observe touches in one menu scroll area; never consume or rewrite input events.
var scroll_area: Control
var deadzone := 14.0
var _pointer := -1
var _origin := Vector2.ZERO
var _dragged := false
var _serial := 0
var _release_frame := -100
var _dispatched_serial := -1
var _pending: Array[Callable] = []

func _input(event: InputEvent) -> void:
 if not is_instance_valid(scroll_area) or not scroll_area.is_visible_in_tree(): return
 observe(event,scroll_area.get_global_rect())

func observe(event: InputEvent, area: Rect2) -> void:
 if event is InputEventScreenTouch:
  if event.pressed:
   if _pointer >= 0:
    _dragged=true
    _pending.clear()
   elif area.has_point(event.position):
    _pointer=event.index
    _origin=event.position
    _dragged=false
    _serial+=1
  elif event.index == _pointer:
   _dragged = _dragged or _origin.distance_to(event.position)>=deadzone
   _pointer=-1
   _release_frame=Engine.get_process_frames()
   if _dragged: _pending.clear()
   else: _flush.call_deferred()
 elif event is InputEventScreenDrag and event.index == _pointer:
  if _origin.distance_to(event.position)>=deadzone:
   _dragged=true
   _pending.clear()

func dispatch(action: Callable) -> void:
 if _pointer>=0:
  if not _dragged and not _pending.has(action): _pending.append(action)
  return
 if Engine.get_process_frames()<=_release_frame+1:
  if _dragged or _dispatched_serial==_serial: return
  _dispatched_serial=_serial
 action.call()

func _flush() -> void:
 var actions := _pending.duplicate()
 _pending.clear()
 for action in actions:
  if not is_inside_tree() or is_queued_for_deletion(): return
  dispatch(action)

func _exit_tree() -> void:
 _pending.clear()
 _pointer=-1
