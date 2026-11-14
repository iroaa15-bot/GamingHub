extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var main=Control.new()
 root.add_child(main)
 main.set_script(load("res://scripts/main.gd"))
 main.sound_enabled=false
 main.reduced_motion=true
 main.age_group="18plus"
 main.show_accessibility()
 var switches=main.root.find_children("*","CheckButton",true,false)
 var valid: bool=switches.size()==3 and not main._admin_ui_authorized()
 main.show_modes(0)
 for control in main.root.find_children("*","Button",true,false): valid=valid and not control.text.contains("مكتبة")
 main.clear_ui()
 var changes=[]
 var control=main.setting_switch("Test",false,func(value: bool): changes.append(value))
 var guard=main._menu_touch_guard
 var press=InputEventScreenTouch.new()
 press.index=0;press.pressed=true;press.position=Vector2(20,20)
 guard.observe(press,Rect2(0,0,100,100))
 control.button_pressed=true
 await process_frame
 var drag=InputEventScreenDrag.new()
 drag.index=0;drag.position=Vector2(20,70)
 guard.observe(drag,Rect2(0,0,100,100))
 press.pressed=false;press.position=Vector2(20,70)
 guard.observe(press,Rect2(0,0,100,100))
 await process_frame
 await process_frame
 valid=valid and changes.is_empty() and not control.button_pressed
 control.button_pressed=true
 await process_frame
 await process_frame
 valid=valid and changes==[true] and control.text.contains("ON")
 control.button_pressed=false
 await process_frame
 await process_frame
 valid=valid and changes==[true,false] and control.text.contains("OFF")
 print("VISUAL_SWITCH_ACCESS_REGRESSION ",valid," — presentation only; no backend/Android test rerun")
 main.queue_free()
 await process_frame
 quit(0 if valid else 1)
