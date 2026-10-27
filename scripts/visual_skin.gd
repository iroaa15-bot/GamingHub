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
  fill_color = Color("0078cf")
  edge_color = Color("36bcff")
 elif tone == "danger":
  fill_color = Color("bb3158")
  edge_color = Color("fa6b8b")
 elif tone == "amber":
  fill_color = Color("af6200")
  edge_color = Color("ffc35a")
 elif tone == "teal":
  fill_color = Color("087e85")
  edge_color = Color("58e4db")
 elif tone == "violet":
  fill_color = Color("5847b7")
  edge_color = Color("ad9dfc")
 target.set_meta("menu_primary",tone=="gold")
 target.set_meta("menu_tone",tone)
 var base: StyleBoxFlat = card(fill_color, 12)
 base.border_color = edge_color
 base.set_border_width_all(2 if tone != "secondary" else 1)
 base.shadow_size = 7
 base.content_margin_top = 8
 base.content_margin_bottom = 8
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
 var text_color: Color = TEXT
 for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
  target.add_theme_color_override(state_name, text_color)
 target.add_theme_color_override("font_disabled_color", MUTED)
 target.add_theme_font_size_override("font_size", 19)
 target.focus_mode = Control.FOCUS_ALL
 target.mouse_filter = Control.MOUSE_FILTER_PASS

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
 panel.mouse_filter = Control.MOUSE_FILTER_PASS
 var skin: StyleBoxFlat = card(Color("162744"), 14)
 skin.border_color = Color("6dcbcf", 0.55)
 skin.set_border_width_all(2)
 skin.content_margin_top = 12
 skin.content_margin_bottom = 12
 panel.add_theme_stylebox_override("panel", skin)
 parent.add_child(panel)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 6)
 panel.add_child(stack)
 var eyebrow := Label.new()
 eyebrow.text = kicker
 eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 eyebrow.add_theme_font_size_override("font_size", 12)
 eyebrow.add_theme_color_override("font_color", SUN)
 stack.add_child(eyebrow)
 var title_label := Label.new()
 title_label.text = title_value
 title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 title_label.add_theme_font_size_override("font_size", 24)
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
 description_label.add_theme_font_size_override("font_size", 14)
 description_label.add_theme_color_override("font_color", MUTED)
 stack.add_child(description_label)


# The approved Hoor & Zain artwork is the actual game identity, not a placeholder.
# Sized for portrait screens, and loaded only on screens that need it.
static func add_brand_banner(parent: VBoxContainer, image_path: String, tagline: String) -> void:
 var panel := PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 panel.mouse_filter = Control.MOUSE_FILTER_PASS
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
 art.custom_minimum_size.y = 124
 art.mouse_filter = Control.MOUSE_FILTER_IGNORE
 art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 stack.add_child(art)
 var tagline_label := Label.new()
 tagline_label.text = tagline
 tagline_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 tagline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 tagline_label.add_theme_font_size_override("font_size", 16)
 tagline_label.add_theme_color_override("font_color", SUN)
 stack.add_child(tagline_label)

static func add_question_panel(parent: VBoxContainer, question_text: String, reading_scale: float = 1.0, eyebrow_text: String = "✦ THE CHALLENGE ✦") -> void:
 var panel := PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 panel.mouse_filter = Control.MOUSE_FILTER_PASS
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
 panel.mouse_filter = Control.MOUSE_FILTER_PASS
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

# Let native ScrollContainer cancel a pressed menu button when a swipe starts.
# Custom scripted controls and explicit gui_input handlers keep their own gestures.
static func enable_menu_swipe(node: Node) -> void:
 if node is Control and node.get_script() == null and node.get_signal_connection_list("gui_input").is_empty():
  if node is Label or node is TextureRect:
   node.mouse_filter = Control.MOUSE_FILTER_IGNORE
  elif (node is Container and not node is ScrollContainer) or node is BaseButton:
   node.mouse_filter = Control.MOUSE_FILTER_PASS
 for child in node.get_children(): enable_menu_swipe(child)

# Presentation-only helpers for the approved compact menu screens.
static var _menu_icons: Dictionary = {}
static func menu_icon(kind: String) -> Texture2D:
 if _menu_icons.has(kind): return _menu_icons[kind]
 var paths := {
  "player":"<circle cx='12' cy='7' r='4'/><path d='M4 22v-3a8 8 0 0 1 16 0v3'/>",
  "phone":"<path d='M5 3h4l2 5-3 2a15 15 0 0 0 6 6l2-3 5 2v4c0 2-2 3-4 2C9 18 5 14 3 6c0-2 0-3 2-3Z'/>",
  "phone_off":"<path d='M5 3h4l2 5-3 2a15 15 0 0 0 6 6l2-3 5 2v4c0 2-2 3-4 2C9 18 5 14 3 6c0-2 0-3 2-3ZM3 3l18 18'/>",
  "back":"<path d='m14 5-7 7 7 7M7 12h14'/>",
  "settings":"<circle cx='12' cy='12' r='4'/><path d='M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10 2 2M5 19l2-2M17 7l2-2'/>",
  "chat":"<path d='M4 4h16v12H9l-5 4Z'/><path d='M8 8h8M8 12h5'/>",
  "list":"<path d='M9 6h12M9 12h12M9 18h12M3 6h1M3 12h1M3 18h1'/>",
  "mic":"<rect x='9' y='2' width='6' height='13' rx='3'/><path d='M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8'/>",
  "mic_off":"<path d='m3 3 18 18M9 9v3a3 3 0 0 0 5 2M9 5a3 3 0 0 1 6 0v6M5 10v2a7 7 0 0 0 12 5M19 10v2M12 19v3M8 22h8'/>"}
 var image := Image.new()
 var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 24 24'><g fill='none' stroke='#f5f7ff' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>%s</g></svg>" % paths.get(kind,paths["settings"])
 if image.load_svg_from_string(svg) != OK: return null
 var texture := ImageTexture.create_from_image(image)
 _menu_icons[kind] = texture
 return texture

static func compact_header(parent: VBoxContainer, title: String) -> void:
 var bar := HBoxContainer.new()
 bar.name = "CompactHeader"
 bar.add_theme_constant_override("separation",12)
 parent.add_child(bar)
 var art := TextureRect.new()
 art.texture = load("res://assets/ui/gaming_hub_brand.png")
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.custom_minimum_size = Vector2(58,58)
 art.mouse_filter = Control.MOUSE_FILTER_IGNORE
 bar.add_child(art)
 var heading := Label.new()
 heading.text = title
 heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 heading.add_theme_font_size_override("font_size",22)
 heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
 bar.add_child(heading)

static func compact_menu(parent: Node) -> void:
 for node in parent.get_children():
  if node is Button and not node is CheckButton:
   var menu_color: Color=Color({"gold":"0078cf","teal":"0078cf","violet":"5140a8","danger":"bb3158","amber":"af6200"}.get(str(node.get_meta("menu_tone","secondary")),"10243b"))
   var style := card(menu_color,12)
   style.border_color = Color("27709c")
   if node.has_meta("compact_game_tile"):
    style.content_margin_left = 4
    style.content_margin_right = 4
   style.content_margin_top = 8
   style.content_margin_bottom = 8
   node.add_theme_stylebox_override("normal",style)
   var pressed := style.duplicate() as StyleBoxFlat
   pressed.bg_color = Color("006fbb")
   node.add_theme_stylebox_override("pressed",pressed)
   node.add_theme_stylebox_override("hover",pressed)
   for state in ["font_color","font_hover_color","font_pressed_color"]: node.add_theme_color_override(state,TEXT)
  compact_menu(node)

static func icon_action(control: Button, kind: String, accessible_label: String) -> void:
 control.icon = menu_icon(kind)
 control.text = ""
 control.tooltip_text = accessible_label
 control.set_meta("accessible_label",accessible_label)
 control.expand_icon = true
 control.add_theme_constant_override("icon_max_width",22)
 control.custom_minimum_size = Vector2(56,56)

static func decorate_switch(control: CheckButton, title: String, enabled: bool) -> void:
 control.text=title+"  "+("ON" if enabled else "OFF")
 control.tooltip_text=title+" • "+("ON" if enabled else "OFF")
 control.set_meta("committed_value",enabled)
 control.add_theme_font_size_override("font_size",17)
 control.add_theme_color_override("font_color",TEXT)
 for on in [false,true]:
  var key := "switch_on" if on else "switch_off"
  if not _menu_icons.has(key):
   var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='28'><rect x='1' y='2' width='46' height='24' rx='12' fill='%s'/><circle cx='%d' cy='14' r='9' fill='#ffffff'/></svg>" % ["#008df0" if on else "#42516b",35 if on else 13]
   var image := Image.new()
   if image.load_svg_from_string(svg)==OK: _menu_icons[key]=ImageTexture.create_from_image(image)
  if _menu_icons.has(key):
   for state in ["checked","checked_mirrored"] if on else ["unchecked","unchecked_mirrored"]:
    control.add_theme_icon_override(state,_menu_icons[key])
 var normal := card(Color("10243b"),12)
 normal.content_margin_left=12
 normal.content_margin_right=12
 normal.content_margin_top=8
 normal.content_margin_bottom=8
 for state in ["normal","hover","pressed"]: control.add_theme_stylebox_override(state,normal)
