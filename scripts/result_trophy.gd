extends Control
## Original vector trophy drawn at runtime for result screens.
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 custom_minimum_size = Vector2(0, 130)

func _draw() -> void:
 var c := Vector2(size.x * .5, 55)
 for i in range(7,0,-1):
  draw_circle(c,float(i)*12,Color("418aff",.024))
 # Draw laurel branches and small confetti as native vectors.
 for side in [-1,1]:
  var direction: float = float(side)
  draw_arc(c + Vector2(direction*12,20), 48, PI*.20 if side==1 else PI*.55, PI*.45 if side==1 else PI*.80, 20, Color("d88e13"), 2.0, true)
  for leaf in range(5):
   var center := c + Vector2(direction*(37.0 + leaf*5.0), 29.0 - leaf*9.0)
   draw_colored_polygon(PackedVector2Array([center+Vector2(0,-8),center+Vector2(direction*7,-4),center+Vector2(direction*5,4),center+Vector2(-direction*3,6)]),Color("ffc93c") if leaf%2==0 else Color("e79a12"))
 for i in range(12):
  var point := c + Vector2(float((i*47)%180)-90,float((i*31)%88)-45)
  var confetti := [Color("f95cdd"),Color("41cfff"),Color("ffd34e")][i%3]
  draw_circle(point,2.0 if i%2==0 else 3.0,confetti)
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
