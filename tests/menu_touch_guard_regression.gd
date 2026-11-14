extends SceneTree
var activations:=0
func activate() -> void: activations+=1
func touch(at: Vector2,down: bool) -> InputEventScreenTouch:
 var event:=InputEventScreenTouch.new()
 event.index=0
 event.position=at
 event.pressed=down
 return event
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var guard=load("res://scripts/menu_touch_guard.gd").new()
 root.add_child(guard)
 var area:=Rect2(0,0,420,840)
 guard.observe(touch(Vector2(100,100),true),area)
 guard.dispatch(activate)
 var waits: bool=activations==0
 var drag:=InputEventScreenDrag.new()
 drag.index=0
 drag.position=Vector2(100,180)
 guard.observe(drag,area)
 guard.observe(touch(Vector2(100,180),false),area)
 guard.dispatch(activate)
 await process_frame
 var cancelled: bool=activations==0
 guard.observe(touch(Vector2(200,200),true),area)
 guard.dispatch(activate)
 guard.observe(touch(Vector2(202,201),false),area)
 guard.dispatch(activate)
 guard.dispatch(activate)
 await process_frame
 var tap_once: bool=activations==1
 await process_frame
 await process_frame
 guard.observe(touch(Vector2(900,900),true),area)
 guard.dispatch(activate)
 var outside: bool=activations==2
 print("MENU_TOUCH_GUARD_REGRESSION ",waits," ",cancelled," ",tap_once," ",outside)
 guard.free()
 quit(0 if waits and cancelled and tap_once and outside else 1)
