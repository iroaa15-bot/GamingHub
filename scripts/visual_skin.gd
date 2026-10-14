extends Control
# Gaming Hub visual identity: lightweight native drawing, no shaders or external assets.
# One coherent skin for the home screen and the online lobby.
const INK := Color("081328")
const MIDNIGHT := Color("111c3b")
const INDIGO := Color("5140a8")
const CYAN := Color("52dfdb")
const SUN := Color("ffd481")
const TEXT := Color("f5f7ff")
const MUTED := Color("b4c4df")

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
 queue_redraw()

func _draw() -> void:
 var size_value: Vector2 = size
 if size_value.x < 1.0 or size_value.y < 1.0:
  return
 # A painted midnight-to-indigo gradient; the backdrop never animates.
 for step in range(28):
  var fraction: float = float(step) / 28.0
  var color_value: Color = INK.lerp(MIDNIGHT, fraction * 0.85)
  draw_rect(Rect2(0.0, size_value.y * fraction, size_value.x, size_value.y / 28.0 + 2.0), color_value)
 # Soft nebula rings and an arch motif make the experience recognizable.
 var scale_value: float = size_value.x / 420.0
 var top_center := Vector2(size_value.x * 0.84, size_value.y * 0.13)
 for radius in range(8, 0, -1):
  draw_circle(top_center, float(radius) * 23.0 * scale_value, Color(0.34, 0.25, 0.78, 0.015))
 var lower_center := Vector2(size_value.x * 0.10, size_value.y * 0.82)
 for radius in range(7, 0, -1):
  draw_circle(lower_center, float(radius) * 27.0 * scale_value, Color(0.05, 0.77, 0.78, 0.010))
 for i in range(28):
  var x: float = float((i * 113 + 29) % 419) / 420.0 * size_value.x
  var y: float = float((i * 193 + 73) % 829) / 830.0 * size_value.y
  var dot_color: Color = CYAN if i % 4 == 0 else SUN
  dot_color.a = 0.14 if i % 3 == 0 else 0.08
  draw_circle(Vector2(x, y), (1.5 if i % 4 == 0 else 1.0) * scale_value, dot_color)

static func card(color_value: Color = Color("182748"), radius: int = 24) -> StyleBoxFlat:
 var box_style := StyleBoxFlat.new()
 box_style.bg_color = color_value
 box_style.set_corner_radius_all(radius)
 box_style.border_color = Color("6376ac", 0.30)
 box_style.set_border_width_all(1)
 box_style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
 box_style.shadow_size = 10
 box_style.shadow_offset = Vector2(0, 5)
 box_style.content_margin_left = 18
 box_style.content_margin_right = 18
 box_style.content_margin_top = 18
 box_style.content_margin_bottom = 18
 return box_style

static func decorate_button(target: Button, tone: String = "secondary") -> void:
 var fill_color: Color = Color("25385d")
 var edge_color: Color = Color("657eae", 0.52)
 if tone == "gold":
  fill_color = Color("f2c76c")
  edge_color = Color("ffe6ad")
 elif tone == "teal":
  fill_color = Color("087e85")
  edge_color = Color("58e4db")
 elif tone == "violet":
  fill_color = Color("5847b7")
  edge_color = Color("ad9dfc")
 var base: StyleBoxFlat = card(fill_color, 19)
 base.border_color = edge_color
 base.set_border_width_all(2 if tone != "secondary" else 1)
 base.shadow_size = 7
 base.content_margin_top = 12
 base.content_margin_bottom = 12
 target.add_theme_stylebox_override("normal", base)
 var hover: StyleBoxFlat = base.duplicate() as StyleBoxFlat
 hover.bg_color = fill_color.lightened(0.10)
 target.add_theme_stylebox_override("hover", hover)
 var pressed: StyleBoxFlat = base.duplicate() as StyleBoxFlat
 pressed.bg_color = fill_color.darkened(0.16)
 pressed.shadow_size = 2
 pressed.shadow_offset = Vector2(0, 1)
 target.add_theme_stylebox_override("pressed", pressed)
 var disabled: StyleBoxFlat = base.duplicate() as StyleBoxFlat
 disabled.bg_color = Color("283148")
 target.add_theme_stylebox_override("disabled", disabled)
 var focus: StyleBoxFlat = base.duplicate() as StyleBoxFlat
 focus.draw_center = false
 focus.border_color = CYAN
 focus.set_border_width_all(2)
 target.add_theme_stylebox_override("focus", focus)
 var text_color: Color = INK if tone == "gold" else TEXT
 for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
  target.add_theme_color_override(state_name, text_color)
 target.add_theme_color_override("font_disabled_color", MUTED)
 target.add_theme_font_size_override("font_size", 19)
 target.focus_mode = Control.FOCUS_ALL

static func decorate_input(target: LineEdit) -> void:
 var input_style: StyleBoxFlat = card(Color("101e38"), 16)
 input_style.border_color = Color("62b9c8", 0.6)
 target.add_theme_stylebox_override("normal", input_style)
 var focus_style: StyleBoxFlat = input_style.duplicate() as StyleBoxFlat
 focus_style.border_color = CYAN
 focus_style.set_border_width_all(2)
 target.add_theme_stylebox_override("focus", focus_style)
 target.add_theme_color_override("font_color", TEXT)
 target.add_theme_color_override("font_placeholder_color", MUTED)
 target.add_theme_color_override("caret_color", SUN)
 target.add_theme_font_size_override("font_size", 18)
 target.custom_minimum_size.y = maxf(target.custom_minimum_size.y, 60.0)

static func add_hero(parent: VBoxContainer, title_value: String, description: String, kicker: String) -> void:
 var panel := PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var skin: StyleBoxFlat = card(Color("222e5e"), 28)
 skin.border_color = Color("6dcbcf", 0.55)
 skin.set_border_width_all(2)
 skin.content_margin_top = 22
 skin.content_margin_bottom = 22
 panel.add_theme_stylebox_override("panel", skin)
 parent.add_child(panel)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 9)
 panel.add_child(stack)
 var eyebrow := Label.new()
 eyebrow.text = "✦  " + kicker + "  ✦"
 eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 eyebrow.add_theme_font_size_override("font_size", 14)
 eyebrow.add_theme_color_override("font_color", SUN)
 stack.add_child(eyebrow)
 var title_label := Label.new()
 title_label.text = title_value
 title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 title_label.add_theme_font_size_override("font_size", 32)
 title_label.add_theme_color_override("font_color", TEXT)
 stack.add_child(title_label)
 var line := ColorRect.new()
 line.color = CYAN
 line.custom_minimum_size.y = 2
 line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 stack.add_child(line)
 var description_label := Label.new()
 description_label.text = description
 description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 description_label.add_theme_font_size_override("font_size", 17)
 description_label.add_theme_color_override("font_color", MUTED)
 stack.add_child(description_label)


# The approved Hoor & Zain artwork is the actual game identity, not a placeholder.
# Sized for portrait screens, and loaded only on screens that need it.
static func add_brand_banner(parent: VBoxContainer, image_path: String, tagline: String) -> void:
 var panel := PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var frame: StyleBoxFlat = card(Color("162653"), 26)
 frame.border_color = Color("ffd481", 0.80)
 frame.set_border_width_all(2)
 frame.content_margin_left = 6
 frame.content_margin_right = 6
 frame.content_margin_top = 6
 frame.content_margin_bottom = 12
 panel.add_theme_stylebox_override("panel", frame)
 parent.add_child(panel)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 5)
 panel.add_child(stack)
 var art := TextureRect.new()
 art.texture = load(image_path) as Texture2D
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.custom_minimum_size.y = 218
 art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 stack.add_child(art)
 var tagline_label := Label.new()
 tagline_label.text = tagline
 tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 tagline_label.add_theme_font_size_override("font_size", 16)
 tagline_label.add_theme_color_override("font_color", SUN)
 stack.add_child(tagline_label)

static func add_question_panel(parent: VBoxContainer, question_text: String, reading_scale: float = 1.0, eyebrow_text: String = "✦ THE CHALLENGE ✦") -> void:
 var panel := PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var skin: StyleBoxFlat = card(Color("21366b"), 22)
 skin.border_color = Color("65e8e0", 0.72)
 skin.set_border_width_all(2)
 panel.add_theme_stylebox_override("panel", skin)
 parent.add_child(panel)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 12)
 panel.add_child(column)
 var eyebrow := Label.new()
 eyebrow.text = eyebrow_text
 eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 eyebrow.add_theme_font_size_override("font_size", 13)
 eyebrow.add_theme_color_override("font_color", SUN)
 column.add_child(eyebrow)
 var title_label := Label.new()
 title_label.text = question_text
 title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title_label.add_theme_font_size_override("font_size", int(24 * reading_scale))
 title_label.add_theme_color_override("font_color", TEXT)
 column.add_child(title_label)

static func add_feedback_panel(parent: VBoxContainer, headline: String, detail: String, is_success: bool) -> void:
 var panel := PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var skin: StyleBoxFlat = card(Color("14554e") if is_success else Color("57364b"), 25)
 skin.border_color = CYAN if is_success else Color("ff9eae")
 skin.set_border_width_all(2)
 panel.add_theme_stylebox_override("panel", skin)
 parent.add_child(panel)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 10)
 panel.add_child(stack)
 var headline_label := Label.new()
 headline_label.text = headline
 headline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 headline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 headline_label.add_theme_font_size_override("font_size", 30)
 headline_label.add_theme_color_override("font_color", SUN if is_success else TEXT)
 stack.add_child(headline_label)
 var detail_label := Label.new()
 detail_label.text = detail
 detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 detail_label.add_theme_font_size_override("font_size", 20)
 detail_label.add_theme_color_override("font_color", TEXT)
 stack.add_child(detail_label)

static func decorate_progress(progress: ProgressBar, gold: bool = false) -> void:
 var track := StyleBoxFlat.new()
 track.bg_color = Color("0d1835")
 track.set_corner_radius_all(9)
 track.content_margin_top = 0
 track.content_margin_bottom = 0
 progress.add_theme_stylebox_override("background", track)
 var fill := StyleBoxFlat.new()
 fill.bg_color = SUN if gold else CYAN
 fill.set_corner_radius_all(9)
 progress.add_theme_stylebox_override("fill", fill)
 progress.custom_minimum_size.y = maxf(progress.custom_minimum_size.y, 15.0)
