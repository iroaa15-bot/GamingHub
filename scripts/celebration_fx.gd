extends Control
# Tiny, deterministic 2D celebration. It does not capture input and auto-frees.
# No shaders, particles, physics bodies, or timers are kept after the animation.
var intensity: float = 1.0
var elapsed: float = 0.0
const DURATION: float = 1.65
const COLORS = [Color("ffd481"), Color("52dfdb"), Color("ff86b9"), Color("b6a4ff"), Color("ffffff")]

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_process(true)
 queue_redraw()

func _process(delta: float) -> void:
 elapsed += delta
 if elapsed >= DURATION:
  queue_free()
  return
 queue_redraw()

func _draw() -> void:
 var count: int = int(52.0 * intensity)
 var fade: float = minf(1.0, (DURATION - elapsed) * 1.6)
 for i in range(count):
  var seed_x: float = float((i * 97 + 17) % 211) / 211.0
  var seed_y: float = float((i * 59 + 43) % 179) / 179.0
  var speed: float = 95.0 + float(i % 7) * 18.0
  var x: float = seed_x * size.x + sin(elapsed * 3.0 + float(i)) * 16.0
  var y: float = seed_y * size.y * 0.45 + elapsed * speed
  var color_value: Color = COLORS[i % COLORS.size()]
  color_value.a = fade * 0.88
  draw_rect(Rect2(x, y, 4.0 + float(i % 3) * 2.0, 6.0 + float(i % 4) * 2.0), color_value)
