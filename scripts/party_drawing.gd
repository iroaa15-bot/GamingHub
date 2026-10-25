extends Control
var strokes: Array = []
var pen_down := false
var read_only := false

func _ready() -> void:
 custom_minimum_size = Vector2(260, 260)
 size_flags_horizontal = Control.SIZE_EXPAND_FILL
 mouse_filter = Control.MOUSE_FILTER_PASS if read_only else Control.MOUSE_FILTER_STOP
 if not read_only:
  set_meta("drawing_input", true)
 queue_redraw()

func _gui_input(event: InputEvent) -> void:
 if read_only:
  return
 var point := Vector2.ZERO
 var begins := false
 var moves := false
 if event is InputEventScreenTouch:
  pen_down = event.pressed
  point = event.position
  begins = event.pressed
 elif event is InputEventScreenDrag:
  point = event.position
  moves = pen_down
 elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
  pen_down = event.pressed
  begins = event.pressed
  point = event.position
 elif event is InputEventMouseMotion:
  point = event.position
  moves = pen_down
 if begins and strokes.size() < 32:
  strokes.append([])
 if (begins or moves) and not strokes.is_empty():
  var total := 0
  for stroke in strokes:
   total += stroke.size()
  if total < 180:
   strokes[-1].append([snappedf(clampf(point.x / maxf(size.x, 1), 0, 1), 0.001), snappedf(clampf(point.y / maxf(size.y, 1), 0, 1), 0.001)])
   queue_redraw()
 accept_event()

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, size), Color("f0f2f6"))
 for stroke in strokes:
  var points := PackedVector2Array()
  for point in stroke:
   points.append(Vector2(float(point[0]), float(point[1])) * size)
  if points.size() > 1:
   draw_polyline(points, Color("19234b"), 4.0, true)

func payload() -> String:
 var usable: Array = []
 for stroke in strokes:
  if stroke.size() >= 2:
   usable.append(stroke)
 return JSON.stringify(usable)
