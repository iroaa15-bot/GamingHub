extends "res://scripts/visual_skin.gd"
## Shared lightweight shell; local game mechanics and source cards stay unchanged.
func _ready() -> void:
 super._ready()
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 name="SocialGameBackdrop"
 var host=get_parent() as Control
 if host==null:return
 var shared_theme:=Theme.new()
 shared_theme.default_font_size=23
 host.theme=shared_theme
 host.layout_direction=Control.LAYOUT_DIRECTION_RTL if load("res://scripts/player_preferences.gd").language()=="ar" else Control.LAYOUT_DIRECTION_LTR
 call_deferred("_decorate_content")
func _decorate_content() -> void:
 var host=get_parent() as Control
 if host==null:return
 var names: Variant=host.get("names_input")
 if is_instance_valid(names) and names is LineEdit and names.is_inside_tree() and not names.has_meta("player_setup_bound"):
  names.set_meta("player_setup_bound",true)
  var setup=load("res://scripts/local_player_setup.gd").new()
  names.get_parent().add_child(setup);names.get_parent().move_child(setup,names.get_index())
  setup.bind_field(names)
 for child in host.get_children():
  if child is ScrollContainer:
   child.offset_left=18;child.offset_right=-18;child.offset_top=18;child.offset_bottom=-18
   child.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 for label in host.find_children("*","Label",true,false):
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  if label.text.contains("مفصولة بفاصلة"):label.hide()
  if label.text.begins_with("الكروت المتاحة"):label.hide()
 for control in host.find_children("*","Button",true,false):
  control.custom_minimum_size.y=maxf(60,control.custom_minimum_size.y)
 compact_menu(host)
 for control in host.find_children("*","Button",true,false):
  if control is OptionButton or control is CheckButton:continue
  decorate_play_action(control,"primary")
 for prompt in host.find_children("SocialPromptCard","PanelContainer",true,false):
  var style:=StyleBoxFlat.new();style.bg_color=Color("edf2fc");style.set_corner_radius_all(22)
  for side in ["left","right","top","bottom"]:style.set("content_margin_"+side,18)
  prompt.add_theme_stylebox_override("panel",style)
 host.modulate.a=1.0
 if not bool(get_tree().root.get_meta("reduced_motion",false)):
  host.modulate.a=.65
  var reveal:=create_tween();reveal.tween_property(host,"modulate:a",1.0,.16)

func _draw() -> void:
 super._draw()

func _notification(what: int) -> void:
 if what!=NOTIFICATION_WM_GO_BACK_REQUEST:return
 if dismiss_text_input(get_viewport()):return
 var host=get_parent()
 if host==null:return
 if host.has_method("_home"):host.call_deferred("_home")
 elif host.has_method("_back"):host.call_deferred("_back")
