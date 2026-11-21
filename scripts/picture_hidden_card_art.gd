extends Control
## Native decoration for the player's concealed card. Never reads or displays
## the secret value; the opponent's visible card remains in the real UI below.

static func attach(main: Control) -> void:
 if main.picture_done or main.root.has_node("PictureHiddenCard"): return
 var card := preload("res://scripts/picture_hidden_card_art.gd").new()
 card.name = "PictureHiddenCard"
 card.custom_minimum_size.y = 142
 card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 card.mouse_filter = Control.MOUSE_FILTER_IGNORE
 main.root.add_child(card)
 # Put the concealed card after the title and current discovery count.
 main.root.move_child(card, mini(2, main.root.get_child_count()-1))
 var question := Label.new()
 question.text = "?"
 question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 question.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 question.add_theme_font_size_override("font_size", 66)
 question.add_theme_color_override("font_color", Color.WHITE)
 question.add_theme_color_override("font_shadow_color", Color("300075"))
 question.add_theme_constant_override("shadow_offset_y", 3)
 question.mouse_filter = Control.MOUSE_FILTER_IGNORE
 card.add_child(question)
 var caption := Label.new()
 caption.text = main.tr_ui("بطاقتك مخفية", "YOUR CARD IS HIDDEN")
 caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 caption.offset_top = -31
 caption.offset_bottom = -8
 caption.add_theme_font_size_override("font_size", 14)
 caption.add_theme_color_override("font_color", Color("f2eaff"))
 caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
 card.add_child(caption)
 for panel in main.root.get_children():
  if panel is PanelContainer:
   var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
   if style != null and style.bg_color.is_equal_approx(Color("1b2b59")):
    var revised: StyleBoxFlat = style.duplicate()
    revised.border_color = Color("43bfff")
    panel.add_theme_stylebox_override("panel", revised)
    break

func _ready() -> void:
 resized.connect(queue_redraw)

func _draw() -> void:
 var bounds := Rect2(Vector2(18,4), size-Vector2(36,8))
 var box := StyleBoxFlat.new()
 box.bg_color=Color("241168")
 box.border_color=Color("d68cff")
 box.set_border_width_all(2)
 box.set_corner_radius_all(18)
 box.shadow_color=Color("722df9",0.38)
 box.shadow_size=10
 draw_style_box(box,bounds)
 var center:=bounds.get_center()
 for ray in range(12):
  var angle:=float(ray)*TAU/12.0
  var a:=center+Vector2.from_angle(angle)*18.0
  var b:=center+Vector2.from_angle(angle)*minf(bounds.size.x*0.37,bounds.size.y*0.58)
  draw_line(a,b,Color("9a66ff",0.18),5.0,true)
 var head:=center+Vector2(0,-19)
 draw_circle(head,24,Color("070b32"))
 draw_circle(center+Vector2(0,33),40,Color("070b32"))
