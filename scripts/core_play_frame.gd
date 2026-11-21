extends RefCounted
const PlaySkin=preload("res://scripts/visual_skin.gd")
const FeedbackEmblem=preload("res://scripts/core_feedback_emblem.gd")
## Reuse real controls and validators in a fixed action dock.
static func style_reference_content(main: Control, kind: String) -> void:
 for child in main.root.get_children():
  if not child is PanelContainer: continue
  var existing := child.get_theme_stylebox("panel") as StyleBoxFlat
  if existing == null: continue
  if kind == "feedback" and (existing.bg_color.is_equal_approx(Color("14554e")) or existing.bg_color.is_equal_approx(Color("57364b"))):
   var success := existing.bg_color.is_equal_approx(Color("14554e"))
   var frame := PlaySkin.play_surface(Color("07183a"),18)
   frame.border_color = Color("36dd62") if success else Color("ff626f")
   frame.set_border_width_all(2)
   child.add_theme_stylebox_override("panel",frame)
   var stack := child.get_child(0) as VBoxContainer
   if stack != null:
    var emblem := FeedbackEmblem.new();emblem.success=success
    stack.add_child(emblem);stack.move_child(emblem,1)
  elif kind == "question":
   var progress: ProgressBar = null
   for candidate in child.find_children("*","ProgressBar",true,false):
    progress=candidate;break
   if progress != null:
    PlaySkin.decorate_progress(progress,false)
    var frame := PlaySkin.play_surface(Color("08183a"),16)
    frame.border_color=Color("469fe8")
    child.add_theme_stylebox_override("panel",frame)
   elif existing.bg_color.is_equal_approx(Color("21366b")):
    var frame := PlaySkin.play_surface(Color("0a1d48"),16)
    frame.border_color=Color("48caff");frame.set_border_width_all(2)
    child.add_theme_stylebox_override("panel",frame)

static func apply(main: Control, generation: int, kind: String) -> void:
 if not is_instance_valid(main) or not main.is_inside_tree() or generation!=main.ui_action_generation or main.has_node("CorePlayDock"):return
 style_reference_content(main,kind)
 if kind=="picture":preload("res://scripts/picture_hidden_card_art.gd").attach(main)
 var scroll=main.root.get_parent().get_parent() as ScrollContainer
 if scroll==null:return
 var compact_view: bool = main.reading_scale>=1.25 or main.get_viewport_rect().size.y<700
 # Result screens can contain several real actions. Let the entire result
 # scroll on compact displays instead of creating an oversized fixed footer.
 if compact_view and kind in ["feedback","results"]:return
 var panel:=PanelContainer.new();panel.name="CorePlayDock"
 panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);panel.grow_vertical=Control.GROW_DIRECTION_BEGIN
 panel.offset_left=16;panel.offset_right=-16;panel.offset_bottom=-24
 var dock_style:=PlaySkin.play_surface(Color("07183d"),20)
 dock_style.border_color=Color("3989ed",0.7)
 dock_style.shadow_color=Color("1956d0",0.22)
 panel.add_theme_stylebox_override("panel",dock_style);main.add_child(panel)
 var controls:=VBoxContainer.new();controls.add_theme_constant_override("separation",8);panel.add_child(controls)
 # On short screens or large text, keep answer inputs in the scrollable body;
 # otherwise the fixed dock can consume the entire view or hide the keyboard.
 var choices=main.root.find_child("CoreAnswerChoices",true,false)
 if choices!=null:
  # Cinema and trivia references place the four full-width answers in a stack.
  # Keep the real buttons/signals and allow the body to scroll for larger text.
  choices.columns=1
  choices.add_theme_constant_override("v_separation",5)
  for choice in choices.get_children():
   if choice is Button:
    PlaySkin.decorate_button(choice,"blue")
    choice.custom_minimum_size.y=46 if main.reading_scale<1.25 else 60
    choice.add_theme_font_size_override("font_size",int(17*main.reading_scale))
  if not compact_view:choices.reparent(controls)
 var navigation:=HBoxContainer.new();navigation.add_theme_constant_override("separation",8)
 for node in main.root.get_children():
  if node is LineEdit and node.get_meta("core_dock",false):
   if not compact_view:node.reparent(controls)
   PlaySkin.decorate_input(node)
  elif node is Button and (node.get_meta("core_dock",false) or kind in ["feedback","results"]):
   if node.get_meta("core_exit",false):node.reparent(navigation);node.custom_minimum_size.y=44
   else:
    if compact_view and kind in ["question","picture","memory"]:continue
    if kind in ["question","feedback"]:PlaySkin.decorate_button(node,"violet")
    node.reparent(controls)
 if kind in ["question","picture","memory"]:
  var pause:=Button.new();pause.text=main.tr_ui("استراحة","Pause");pause.custom_minimum_size.y=44
  pause.size_flags_horizontal=Control.SIZE_EXPAND_FILL;PlaySkin.decorate_button(pause,"secondary")
  pause.pressed.connect(main.pause_local_play);navigation.add_child(pause)
 if navigation.get_child_count()>0:controls.add_child(navigation)
 else:navigation.free()
 var resize_dock:=func():
  if not is_instance_valid(panel) or not is_instance_valid(scroll):return
  var height: float=panel.get_combined_minimum_size().y
  panel.offset_top=-height-24;scroll.offset_bottom=-height-40
 panel.minimum_size_changed.connect(resize_dock);resize_dock.call_deferred()
 # A focused answer can otherwise make a newly opened round scroll past its
 # title while the dock is being reparented on touch devices.
 main.get_tree().process_frame.connect(func():
  if is_instance_valid(scroll) and is_instance_valid(main) and generation==main.ui_action_generation:
   scroll.scroll_vertical=0
 ,CONNECT_ONE_SHOT)
