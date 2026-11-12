extends Control
## Full-viewport composition using the approved artwork unchanged.
const ART=preload("res://assets/ui/gaming_hub_brand.png")
var hero: TextureRect
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 hero=TextureRect.new()
 hero.texture=ART
 hero.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 hero.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 hero.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var material_value:=ShaderMaterial.new()
 material_value.shader=preload("res://scripts/welcome_art_blend.gdshader")
 hero.material=material_value
 add_child(hero)
 resized.connect(_layout)
 _layout()
func _layout() -> void:
 if hero==null:return
 var side: float=minf(size.x*1.04,size.y*0.64)
 hero.position=Vector2((size.x-side)/2,maxf(90,size.y*0.12))
 hero.size=Vector2(side,side)
 queue_redraw()
func _draw() -> void:
 for step in range(32):
  var t: float=float(step)/31.0
  draw_rect(Rect2(0,size.y*t,size.x,size.y/31.0+2),Color("2361c9").lerp(Color("080b35"),t))
 for radius in range(6,0,-1):
  draw_circle(Vector2(size.x*0.1,size.y*0.78),float(radius)*24,Color(0.1,0.8,1.0,0.025))
  draw_circle(Vector2(size.x*0.9,size.y*0.26),float(radius)*22,Color(0.6,0.3,1.0,0.025))
