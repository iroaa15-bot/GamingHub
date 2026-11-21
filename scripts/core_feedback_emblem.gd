extends Control
## Decorative status indicator; the result and score remain supplied by the game.
var success := false

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 custom_minimum_size.y = 130
 resized.connect(queue_redraw)

func _draw() -> void:
 var center := size * 0.5
 var accent := Color("40f066") if success else Color("ff606c")
 for radius in range(7, 0, -1):
  var haze := accent
  haze.a = 0.018 + (7 - radius) * 0.007
  draw_circle(center, float(radius) * 11.5, haze)
 draw_circle(center, 43, Color("075b24") if success else Color("711628"))
 draw_arc(center, 43, 0, TAU, 64, accent, 3.0, true)
 if success:
  draw_polyline(PackedVector2Array([center+Vector2(-22,1),center+Vector2(-7,16),center+Vector2(25,-18)]), Color.WHITE, 8.0, true)
 else:
  draw_line(center+Vector2(-17,-17),center+Vector2(17,17),Color.WHITE,8.0,true)
  draw_line(center+Vector2(17,-17),center+Vector2(-17,17),Color.WHITE,8.0,true)
