extends Control
# Gaming Hub visual identity: lightweight native drawing, no shaders or external assets.
# One coherent skin for the home screen and the online lobby.
const INK := Color("030a28")
const MIDNIGHT := Color("121044")
const INDIGO := Color("761ee8")
const CYAN := Color("15e7ff")
const SUN := Color("ffcc42")
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
  draw_circle(top_center, float(radius) * 23.0 * scale_value, Color(0.42, 0.08, 0.94, 0.027))
 var lower_center := Vector2(size_value.x * 0.10, size_value.y * 0.82)
 for radius in range(7, 0, -1):
  draw_circle(lower_center, float(radius) * 27.0 * scale_value, Color(0.01, 0.60, 1.0, 0.023))
 for i in range(28):
  var x: float = float((i * 113 + 29) % 419) / 420.0 * size_value.x
  var y: float = float((i * 193 + 73) % 829) / 830.0 * size_value.y
  var dot_color: Color = CYAN if i % 4 == 0 else SUN
  dot_color.a = 0.42 if i % 3 == 0 else 0.16
  draw_circle(Vector2(x, y), (1.5 if i % 4 == 0 else 1.0) * scale_value, dot_color)

static func card(color_value: Color = Color("182748"), radius: int = 24) -> StyleBoxFlat:
 var box_style := StyleBoxFlat.new()
 box_style.bg_color = color_value
 box_style.set_corner_radius_all(radius)
 box_style.border_color = Color("24c6ff", 0.65)
 box_style.set_border_width_all(1)
 box_style.shadow_color = Color(0.07, 0.29, 1.0, 0.22)
 box_style.shadow_size = 6
 box_style.shadow_offset = Vector2(0, 5)
 box_style.content_margin_left = 18
 box_style.content_margin_right = 18
 box_style.content_margin_top = 18
 box_style.content_margin_bottom = 18
 return box_style

static var _neon_textures: Dictionary={}
# Cached 64px nine-slice surfaces: beveled neon depth without shaders or per-frame effects.
static func neon_surface(fill: Color, edge: Color) -> StyleBoxTexture:
 var key: String=fill.to_html()+edge.to_html()
 if not _neon_textures.has(key):
  var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
  for y in range(64):
   for x in range(64):
    var q: Vector2=(Vector2(x+0.5,y+0.5)-Vector2(32,32)).abs()-Vector2(14,14)
    var d: float=q.max(Vector2.ZERO).length()+minf(maxf(q.x,q.y),0.0)-12.0
    var color := Color.TRANSPARENT
    if d<=0:
     color=fill.lightened(0.22).lerp(fill.darkened(0.32),clampf(float(y-5)/54.0,0.0,1.0))
     if d>-1.7:color=edge
     elif y<13:color=color.lerp(Color.WHITE,0.20)
    elif d<5:
     color=edge;color.a=0.26*pow(1.0-d/5.0,2)
    image.set_pixel(x,y,color)
  _neon_textures[key]=ImageTexture.create_from_image(image)
 var surface := StyleBoxTexture.new()
 surface.texture=_neon_textures[key]
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
  surface.set_texture_margin(side,18)
  surface.set_expand_margin(side,5)
 surface.content_margin_left=14;surface.content_margin_right=14
 surface.content_margin_top=10;surface.content_margin_bottom=10
 return surface

static func decorate_button(target: Button, tone: String = "secondary") -> void:
 var palette: Dictionary={"secondary":["0c1d51","247aca"],"gold":["008cff","26f4ff"],"blue":["008cff","26f4ff"],"teal":["00b94c","56ffbd"],"violet":["6c20df","f459ff"],"danger":["ed264f","ff939e"],"amber":["ec8a05","ffe67a"]}
 var colors: Array=palette.get(tone,palette.secondary)
 var fill:=Color(colors[0]);var edge:=Color(colors[1])
 target.set_meta("menu_primary",tone in ["gold","blue"])
 target.set_meta("menu_tone",tone)
 var normal:=neon_surface(fill,edge)
 target.add_theme_stylebox_override("normal",normal)
 target.add_theme_stylebox_override("hover",neon_surface(fill.lightened(0.08),edge.lightened(0.10)))
 target.add_theme_stylebox_override("pressed",neon_surface(fill.darkened(0.20),edge))
 target.add_theme_stylebox_override("disabled",neon_surface(Color("18234b"),Color("33436c")))
 var focus:=card(Color.TRANSPARENT,14)
 focus.draw_center=false;focus.border_color=CYAN;focus.set_border_width_all(2)
 target.add_theme_stylebox_override("focus",focus)
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:target.add_theme_color_override(state,TEXT)
 target.add_theme_color_override("font_disabled_color",MUTED)
 target.add_theme_color_override("font_shadow_color",Color("031034"))
 target.add_theme_constant_override("shadow_offset_x",0);target.add_theme_constant_override("shadow_offset_y",1)
 target.add_theme_font_size_override("font_size",19)
 target.focus_mode=Control.FOCUS_ALL
 target.mouse_filter=Control.MOUSE_FILTER_PASS

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
  "settings":"<path d='m9 3-.5 2-2 1-2-.5-2 3L4 10v3l-1.5 1.5 2 3 2-.5 2 1 .5 3h5l.5-3 2-1 2 .5 2-3L20 13v-3l1.5-1.5-2-3-2 .5-2-1L14 3Z'/><circle cx='12' cy='12' r='3'/>",
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
  if node is Button and not node is CheckButton and not node is OptionButton:
   var font_size: int=node.get_theme_font_size("font_size")
   decorate_button(node,str(node.get_meta("menu_tone","secondary")))
   node.add_theme_font_size_override("font_size",font_size)
   if node.has_meta("compact_game_tile"):
    for state in ["normal","hover","pressed","disabled"]:
     var style: StyleBox=node.get_theme_stylebox(state)
     style.content_margin_left=4;style.content_margin_right=4
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

static var _game_covers: Dictionary={}
static func game_cover(index: int) -> Texture2D:
 if _game_covers.has(index):return _game_covers[index]
 var paths: Array=["","<path d='M8 16h32v25H8zM8 9l30-5 2 9-31 6zM15 8l6 8M26 6l6 8'/>","<path d='M11 12h26v28H11zM17 21h14M17 28h10M17 35h14'/>","<path d='M13 34c-12-8-4-24 7-20 4-12 22-7 20 4 12 7 4 21-6 20H14M24 13v25M14 21h7M28 20h8M30 29h8'/>","<path d='m6 39 14-29 7 16 6-12 10 25zM20 11v-5l12 3-12 4'/>","<path d='M15 8h18v18c0 11-18 11-18 0zM15 12H8v9c0 7 9 8 9 8M33 12h7v9c0 7-9 8-9 8M24 33v8M16 42h16'/>","<path d='M6 21v8M12 15v20M18 9v30M24 17v14M30 5v38M36 12v24M42 19v10'/>","<circle cx='24' cy='17' r='9'/><path d='M9 43v-3c0-16 30-16 30 0v3M21 15c0-5 9-4 6 1l-3 3M24 23v1'/>","<path d='m6 12 22-5 7 32-22 5zM24 10l17 4-6 28M16 24l5-6 7 10-5 7z'/>","<path d='M10 10h6M10 24h6M10 38h6M23 10h17M23 24h17M23 38h17'/>"]
 var colors: Array=["ffb01c","b343ff","008eff","9a34f0","02bfa8","ffb01c","00cffa","02bfc2","a129ec","239cff"]
 var body: String=str(paths[clampi(index,0,9)])
 var svg: String="<svg xmlns='http://www.w3.org/2000/svg' width='96' height='96' viewBox='0 0 48 48'><defs><linearGradient id='g' x2='0.8' y2='1'><stop stop-color='#ffffff' stop-opacity='.28'/><stop offset='.5' stop-color='#"+str(colors[index])+"'/><stop offset='1' stop-color='#111044'/></linearGradient></defs><rect x='2' y='2' width='44' height='44' rx='11' fill='url(#g)' stroke='#"+str(colors[index])+"' stroke-width='2'/><g fill='none' stroke='#fff4bc' stroke-width='2.4' stroke-linecap='round' stroke-linejoin='round'>"+body+"</g></svg>"
 var image:=Image.new()
 if image.load_svg_from_string(svg)!=OK:return menu_icon("player")
 _game_covers[index]=ImageTexture.create_from_image(image)
 return _game_covers[index]
