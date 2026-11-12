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
 for child in host.get_children():
  if child is ScrollContainer:
   child.offset_left=18;child.offset_right=-18;child.offset_top=18;child.offset_bottom=-18
   child.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 for label in host.find_children("*","Label",true,false):
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 for control in host.find_children("*","Button",true,false):
  control.custom_minimum_size.y=maxf(60,control.custom_minimum_size.y)
 compact_menu(host)

func _notification(what: int) -> void:
 if what!=NOTIFICATION_WM_GO_BACK_REQUEST:return
 if dismiss_text_input(get_viewport()):return
 var host=get_parent()
 if host==null:return
 if host.has_method("_home"):host.call_deferred("_home")
 elif host.has_method("_back"):host.call_deferred("_back")
