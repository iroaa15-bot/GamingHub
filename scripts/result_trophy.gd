extends Control
## Original vector trophy drawn at runtime for result screens.
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 custom_minimum_size = Vector2(0, 112)

func _draw() -> void:
 var c := Vector2(size.x * .5, 50)
 for i in range(7,0,-1):
  draw_circle(c,float(i)*11,Color("ffcb41",.025))
 var gold := Color("ffcb39")
 var highlight := Color("fff3a0")
 draw_arc(c+Vector2(-32,-12),18,-PI*.82,PI*.50,24,gold,5,true)
 draw_arc(c+Vector2(32,-12),18,PI*.50,PI*1.82,24,gold,5,true)
 draw_colored_polygon(PackedVector2Array([c+Vector2(-32,-34),c+Vector2(32,-34),c+Vector2(26,4),c+Vector2(15,18),c+Vector2(-15,18),c+Vector2(-26,4)]),gold)
 draw_colored_polygon(PackedVector2Array([c+Vector2(-24,-28),c+Vector2(24,-28),c+Vector2(19,1),c+Vector2(12,12),c+Vector2(-12,12),c+Vector2(-19,1)]),Color("f49a08"))
 draw_line(c+Vector2(-30,-34),c+Vector2(30,-34),highlight,3,true)
 draw_rect(Rect2(c+Vector2(-5,18),Vector2(10,14)),gold)
 draw_rect(Rect2(c+Vector2(-23,30),Vector2(46,7)),gold)
 draw_rect(Rect2(c+Vector2(-30,37),Vector2(60,9)),Color("d87d08"))
 var star := PackedVector2Array()
 for i in range(10):
  var r: float=14 if i%2==0 else 6
  star.append(c+Vector2.from_angle(-PI/2+float(i)*PI/5)*r+Vector2(0,-10))
 draw_colored_polygon(star,highlight)
