extends Control
static func dismiss_text_input(viewport: Viewport) -> bool:
 if viewport.get_meta("text_back_frame",-1)==Engine.get_process_frames():return true
 var focus:=viewport.gui_get_focus_owner()
 if not (focus is LineEdit or focus is TextEdit):return false
 viewport.set_meta("text_back_frame",Engine.get_process_frames())
 focus.release_focus()
 DisplayServer.virtual_keyboard_hide()
 return true
# Gaming Hub visual identity: lightweight native drawing, no shaders or external assets.
# One coherent skin for the home screen and the online lobby.
const INK := Color("070b32")
const MIDNIGHT := Color("25105c")
const INDIGO := Color("761ee8")
const CYAN := Color("15e7ff")
const SUN := Color("ffcc42")
const TEXT := Color("f5f7ff")
const MUTED := Color("b4c4df")

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
 var catalog := get_node_or_null("/root/PublishedContent")
 if catalog != null: catalog.changed.connect(queue_redraw)
 queue_redraw()

static func remote_settings() -> Dictionary:
 var tree := Engine.get_main_loop() as SceneTree
 if tree == null: return {}
 var catalog := tree.root.get_node_or_null("PublishedContent")
 return catalog.settings if catalog != null else {}

func _draw() -> void:
 var size_value: Vector2 = size
 if size_value.x < 1.0 or size_value.y < 1.0:
  return
 # A painted midnight-to-indigo gradient; the backdrop never animates.
 for step in range(28):
  var fraction: float = float(step) / 28.0
  var presentation: Dictionary = remote_settings()
  var color_value: Color = Color(presentation.get("background",INK)).lerp(Color(presentation.get("background_end",MIDNIGHT)), fraction * 0.85)
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
 # Low-contrast castle silhouettes echo the supplied lobby artwork without
 # embedding reference screenshots, labels or controls into the background.
 for side in [0,1]:
  var x: float=size_value.x*(0.07 if side==0 else 0.93)
  var base: float=size_value.y*0.31
  var width: float=25*scale_value
  draw_rect(Rect2(x-width/2,base-105*scale_value,width,105*scale_value),Color("172669",0.52))
  draw_colored_polygon(PackedVector2Array([Vector2(x-width*.8,base-105*scale_value),Vector2(x,base-146*scale_value),Vector2(x+width*.8,base-105*scale_value)]),Color("273c98",0.5))
  draw_rect(Rect2(x-3*scale_value,base-87*scale_value,6*scale_value,18*scale_value),Color("47dafa",0.19))
 var rim:=card(Color.TRANSPARENT,26)
 rim.draw_center=false;rim.border_color=Color("887cff",0.42);rim.set_border_width_all(1)
 rim.shadow_size=0
 draw_style_box(rim,Rect2(Vector2(6,6),size_value-Vector2(12,12)))

static func card(color_value: Color = Color("182748"), radius: int = 24) -> StyleBoxFlat:
 var box_style := StyleBoxFlat.new()
 box_style.bg_color = color_value
 box_style.set_corner_radius_all(radius)
 box_style.border_color = Color("9b86ff", 0.78)
 box_style.set_border_width_all(2)
 box_style.shadow_color = Color(0.22, 0.11, 1.0, 0.24)
 box_style.shadow_size = 8
 box_style.shadow_offset = Vector2(0, 5)
 box_style.content_margin_left = 18
 box_style.content_margin_right = 18
 box_style.content_margin_top = 18
 box_style.content_margin_bottom = 18
 return box_style

static var _neon_textures: Dictionary={}
# Cached antialiased nine-slice surfaces; generated once per palette, no per-frame work.
static func neon_surface(fill: Color, edge: Color) -> StyleBoxTexture:
 var key: String=fill.to_html()+edge.to_html()
 if not _neon_textures.has(key):
  var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
  for y in range(128):
   for x in range(128):
    var q: Vector2=(Vector2(x+0.5,y+0.5)/2.0-Vector2(32,32)).abs()-Vector2(14,14)
    var d: float=q.max(Vector2.ZERO).length()+minf(maxf(q.x,q.y),0.0)-12.0
    var color := Color.TRANSPARENT
    if d<=0:
     color=fill.lightened(0.22).lerp(fill.darkened(0.32),clampf((float(y)/2.0-5.0)/54.0,0.0,1.0))
     if d>-1.7:color=edge
     elif y<26:color=color.lerp(Color.WHITE,0.20)
    elif d<5:
     color=edge;color.a=0.26*pow(1.0-d/5.0,2)
    if d>-.5 and d<.5:color.a=lerpf(1.0,0.26,clampf(d+.5,0.0,1.0))
    image.set_pixel(x,y,color)
  image.resize(64,64,Image.INTERPOLATE_LANCZOS)
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
 var palette: Dictionary={"secondary":["28166b","a28aff"],"gold":["007cde","59eeff"],"blue":["007cde","59eeff"],"teal":["06a52e","a4ff53"],"violet":["7022dd","ef91ff"],"danger":["d91b51","ff8fae"],"amber":["e9a008","fff19a"]}
 var colors: Array=palette.get(tone,palette.secondary)
 var fill:=Color(colors[0]);var edge:=Color(colors[1])
 if tone in ["secondary", "gold", "blue"] and remote_settings().get("custom_primary",false):
  fill=Color(remote_settings().primary)
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

static func add_social_prompt(parent: VBoxContainer, category: String, text: String) -> PanelContainer:
 var panel:=PanelContainer.new()
 panel.name="SocialPromptCard"
 panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 panel.custom_minimum_size.y=190
 var skin:=card(Color("fff0d1"),22)
 skin.border_color=Color("f9c557");skin.set_border_width_all(3)
 skin.shadow_color=Color("7026be",0.4);skin.shadow_size=8
 panel.add_theme_stylebox_override("panel",skin);parent.add_child(panel)
 var content:=VBoxContainer.new();content.add_theme_constant_override("separation",14);panel.add_child(content)
 var badge:=Label.new();badge.text=category;badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 badge.add_theme_font_size_override("font_size",18);badge.add_theme_color_override("font_color",Color("74256c"));content.add_child(badge)
 var prompt:=Label.new();prompt.name="PromptText";prompt.text=text
 prompt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;prompt.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 prompt.size_flags_vertical=Control.SIZE_EXPAND_FILL
 prompt.add_theme_font_size_override("font_size",25);prompt.add_theme_color_override("font_color",Color("25163e"))
 content.add_child(prompt)
 enable_menu_swipe(panel)
 return panel

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
static func language_globe() -> Texture2D:
 if _menu_icons.has("language_globe"):return _menu_icons["language_globe"]
 # Rasterized once at 3x the visible size; no 3D viewport or per-frame shader.
 var svg := """<svg xmlns='http://www.w3.org/2000/svg' width='168' height='168' viewBox='0 0 64 64'>
 <defs><radialGradient id='ocean' cx='.32' cy='.23' r='.8'><stop stop-color='#b6ffff'/><stop offset='.28' stop-color='#28c9f7'/><stop offset='.65' stop-color='#1265c7'/><stop offset='1' stop-color='#122353'/></radialGradient>
 <linearGradient id='land' x2='.8' y2='1'><stop stop-color='#ddffff'/><stop offset='.6' stop-color='#59ebdf'/><stop offset='1' stop-color='#168eae'/></linearGradient>
 <clipPath id='sphere'><circle cx='32' cy='29' r='25'/></clipPath></defs>
 <ellipse cx='33' cy='58' rx='22' ry='4' fill='#020a25' opacity='.7'/>
 <circle cx='32' cy='29' r='28' fill='#1fc8ff' opacity='.13'/>
 <circle cx='32' cy='29' r='25' fill='url(#ocean)' stroke='#66edff' stroke-width='1.5'/>
 <g clip-path='url(#sphere)'><g fill='none' stroke='#b5ffff' opacity='.3'><ellipse cx='32' cy='29' rx='12' ry='25'/><path d='M7 29h50M11 17q21 10 42 0M11 41q21-10 42 0'/></g>
 <g fill='url(#land)' stroke='#147fa4' stroke-width='.5'><path d='m15 11 10-4 6 5-3 6-5 1-2 6-5-1-2-7-5-2Zm8 16 7 1 4 7-4 6-2 10-5-5-2-10-4-4Z'/><path d='m38 8 12 5 7 7-6 7-6-2-2 6-6-2-4-8 4-4Zm5 30 9 1 4 7-9 3-6-5Z'/></g>
 <ellipse cx='23' cy='13' rx='14' ry='7' fill='#fff' opacity='.24' transform='rotate(-28 23 13)'/></g>
 <path d='M13 22A21 21 0 0 1 29 8' fill='none' stroke='#edffff' stroke-width='2' stroke-linecap='round'/>
 <path d='m53 5 1 3 3 1-3 1-1 3-1-3-3-1 3-1Z' fill='#d9ffff'/></svg>"""
 var image := Image.new()
 if image.load_svg_from_string(svg)!=OK:return menu_icon("globe")
 var texture := ImageTexture.create_from_image(image)
 _menu_icons["language_globe"]=texture
 return texture

static func menu_icon(kind: String) -> Texture2D:
 if _menu_icons.has(kind): return _menu_icons[kind]
 var paths := {
  "globe":"<circle cx='12' cy='12' r='10'/><ellipse cx='12' cy='12' rx='4' ry='10'/><path d='M2 12h20M4 6h16M4 18h16'/>",
  "share":"<circle cx='18' cy='5' r='3'/><circle cx='6' cy='12' r='3'/><circle cx='18' cy='19' r='3'/><path d='m8 10 7-4M8 14l7 4'/>",
  "player":"<circle cx='12' cy='7' r='4'/><path d='M4 22v-3a8 8 0 0 1 16 0v3'/>",
  "phone":"<path d='M5 3h4l2 5-3 2a15 15 0 0 0 6 6l2-3 5 2v4c0 2-2 3-4 2C9 18 5 14 3 6c0-2 0-3 2-3Z'/>",
  "phone_off":"<path d='M5 3h4l2 5-3 2a15 15 0 0 0 6 6l2-3 5 2v4c0 2-2 3-4 2C9 18 5 14 3 6c0-2 0-3 2-3ZM3 3l18 18'/>",
  "back":"<path d='m14 5-7 7 7 7M7 12h14'/>",
  "settings":"<path d='m9 3-.5 2-2 1-2-.5-2 3L4 10v3l-1.5 1.5 2 3 2-.5 2 1 .5 3h5l.5-3 2-1 2 .5 2-3L20 13v-3l1.5-1.5-2-3-2 .5-2-1L14 3Z'/><circle cx='12' cy='12' r='3'/>",
  "chat":"<path d='M4 4h16v12H9l-5 4Z'/><path d='M8 8h8M8 12h5'/>",
  "list":"<path d='M9 6h12M9 12h12M9 18h12M3 6h1M3 12h1M3 18h1'/>",
  "copy":"<rect x='8' y='7' width='12' height='14' rx='2'/><path d='M15 7V3H4v14h4'/>",
  "plus":"<path d='M12 5v14M5 12h14'/>",
  "mic":"<rect x='9' y='2' width='6' height='13' rx='3'/><path d='M5 10v2a7 7 0 0 0 14 0v-2M12 19v3M8 22h8'/>",
  "mic_off":"<path d='m3 3 18 18M9 9v3a3 3 0 0 0 5 2M9 5a3 3 0 0 1 6 0v6M5 10v2a7 7 0 0 0 12 5M19 10v2M12 19v3M8 22h8'/>"}
 var image := Image.new()
 var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 32 32'><defs><linearGradient id='badge' x2='.8' y2='1'><stop stop-color='#6cecff'/><stop offset='.45' stop-color='#1454be'/><stop offset='1' stop-color='#32116d'/></linearGradient><linearGradient id='metal' x2='.4' y2='1'><stop stop-color='#ffffff'/><stop offset='.45' stop-color='#b9faff'/><stop offset='1' stop-color='#37a9ed'/></linearGradient></defs><rect x='2' y='4' width='28' height='27' rx='9' fill='#080b32'/><rect x='2' y='1' width='28' height='28' rx='9' fill='url(#badge)' stroke='#38e2ff'/><path d='M6 8Q6 4 11 4h10' fill='none' stroke='#dcffff' stroke-opacity='.7' stroke-linecap='round'/><g transform='translate(4 5)' fill='none' stroke='#11265f' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'>%s</g><g transform='translate(4 3)' fill='none' stroke='url(#metal)' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>%s</g></svg>" % [paths.get(kind,paths["settings"]),paths.get(kind,paths["settings"])]
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

static func decorate_selector(control: OptionButton) -> void:
 control.custom_minimum_size.y=maxf(control.custom_minimum_size.y,52)
 control.add_theme_stylebox_override("normal",neon_surface(Color("183b69"),Color("36cfff")))
 control.add_theme_stylebox_override("hover",neon_surface(Color("325aa2"),Color("84f7ff")))
 control.add_theme_stylebox_override("pressed",neon_surface(Color("5838a4"),Color("d8a0ff")))
 control.add_theme_stylebox_override("disabled",neon_surface(Color("253452"),Color("657993")))
 for state in ["normal","hover","pressed","disabled"]:
  control.add_theme_stylebox_override(state+"_mirrored",control.get_theme_stylebox(state))
 control.add_theme_color_override("font_color",TEXT)
 control.add_theme_color_override("font_disabled_color",Color("b1bfd4"))
 control.add_theme_constant_override("h_separation",12)
 var popup=control.get_popup()
 popup.add_theme_stylebox_override("panel",card(Color("12284b"),18))
 popup.add_theme_stylebox_override("hover",card(Color("50369a"),12))
 popup.add_theme_color_override("font_color",TEXT)
 popup.add_theme_color_override("font_hover_color",Color("fff0b5"))
 popup.add_theme_constant_override("v_separation",16)
 if not control.has_meta("premium_selection_sound"):
  control.set_meta("premium_selection_sound",true)
  control.item_selected.connect(func(_index: int):load("res://scripts/room_audio_policy.gd").acquire(control.get_tree()).effect("selection",true))

static func compact_menu(parent: Node) -> void:
 for node in parent.get_children():
  if node is OptionButton:decorate_selector(node)
  elif node is SpinBox:
   node.custom_minimum_size.y=maxf(node.custom_minimum_size.y,52)
   var edit: LineEdit=node.get_line_edit()
   edit.add_theme_stylebox_override("normal",neon_surface(Color("183b69"),Color("36cfff")))
   edit.add_theme_stylebox_override("focus",neon_surface(Color("325aa2"),CYAN))
   edit.add_theme_color_override("font_color",TEXT)
  elif node is LineEdit:
   node.add_theme_stylebox_override("normal",neon_surface(Color("102d50"),Color("537da6")))
   node.add_theme_stylebox_override("focus",neon_surface(Color("193a62"),CYAN))
   node.add_theme_color_override("font_color",TEXT)
   node.add_theme_color_override("font_placeholder_color",Color("afc7df"))
  if node is Button and not node is CheckButton and not node is OptionButton and not node.has_meta("language_switcher") and not node.has_meta("provider_brand"):
   var font_size: int=node.get_theme_font_size("font_size")
   decorate_button(node,str(node.get_meta("menu_tone","secondary")))
   node.add_theme_font_size_override("font_size",font_size)
   if node.has_meta("compact_game_tile"):
    for state in ["normal","hover","pressed","disabled"]:
     var style: StyleBox=node.get_theme_stylebox(state)
     style.content_margin_left=4;style.content_margin_right=4
  if node is Label or node is Button:
   if not node.has_meta("admin_base_font_size"):
    node.set_meta("admin_base_font_size",node.get_theme_font_size("font_size"))
   var scale_value: float=float(remote_settings().get("font_scale",1.0))
   node.add_theme_font_size_override("font_size",roundi(int(node.get_meta("admin_base_font_size"))*scale_value))
  compact_menu(node)

static func icon_action(control: Button, kind: String, accessible_label: String) -> void:
 control.icon = menu_icon(kind)
 control.text = ""
 control.tooltip_text = accessible_label
 control.set_meta("accessible_label",accessible_label)
 control.expand_icon = true
 control.add_theme_constant_override("icon_max_width",30)
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
 var premium: Dictionary={0:"picture_icon_v1.png",1:"cinema_icon_v1.png",6:"sound_icon_v1.png",3:"brain_icon_v1.png",8:"memory_icon_v1.png",9:"ordering_icon_v1.png",2:"writing_icon_v1.png",4:"adventure_icon_v1.png",5:"knowledge_icon_v1.png",7:"identity_icon_v1.png"}
 if premium.has(index):
  var resource: String="res://assets/ui/premium/"+str(premium[index])
  if ResourceLoader.exists(resource):
   _game_covers[index]=load(resource)
   return _game_covers[index]
 if index==0:return null
 var paths: Array=["","<path d='M8 16h32v25H8zM8 9l30-5 2 9-31 6zM15 8l6 8M26 6l6 8'/>","<path d='M11 12h26v28H11zM17 21h14M17 28h10M17 35h14'/>","<path d='M13 34c-12-8-4-24 7-20 4-12 22-7 20 4 12 7 4 21-6 20H14M24 13v25M14 21h7M28 20h8M30 29h8'/>","<path d='m6 39 14-29 7 16 6-12 10 25zM20 11v-5l12 3-12 4'/>","<path d='M15 8h18v18c0 11-18 11-18 0zM15 12H8v9c0 7 9 8 9 8M33 12h7v9c0 7-9 8-9 8M24 33v8M16 42h16'/>","<path d='M6 21v8M12 15v20M18 9v30M24 17v14M30 5v38M36 12v24M42 19v10'/>","<circle cx='24' cy='17' r='9'/><path d='M9 43v-3c0-16 30-16 30 0v3M21 15c0-5 9-4 6 1l-3 3M24 23v1'/>","<path d='m6 12 22-5 7 32-22 5zM24 10l17 4-6 28M16 24l5-6 7 10-5 7z'/>","<path d='M10 10h6M10 24h6M10 38h6M23 10h17M23 24h17M23 38h17'/>"]
 var colors: Array=["ffb01c","b343ff","008eff","9a34f0","02bfa8","ffb01c","00cffa","02bfc2","a129ec","239cff"]
 var body: String=str(paths[clampi(index,0,9)])
 var tone: String=str(colors[clampi(index,0,9)])
 var jewel: Color=Color(["ffcf42","a985ff","65dfff","ff83c7","77f1bf","ffd14c","fa75ed","ffc075","83dfff","66efda"][clampi(index,0,9)])
 var light: String=jewel.lightened(.6).to_html(false)
 var mid: String=jewel.to_html(false)
 var deep: String=jewel.darkened(.48).to_html(false)
 var svg: String="<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128' viewBox='0 0 48 48'><defs><linearGradient id='g' x2='.7' y2='1'><stop stop-color='#caffff'/><stop offset='.23' stop-color='#"+tone+"'/><stop offset='1' stop-color='#221457'/></linearGradient><linearGradient id='gold' x2='.3' y2='1'><stop stop-color='#"+light+"'/><stop offset='.35' stop-color='#"+mid+"'/><stop offset='.7' stop-color='#"+mid+"'/><stop offset='1' stop-color='#"+deep+"'/></linearGradient><linearGradient id='glass' x2='.3' y2='1'><stop stop-color='#ffffff' stop-opacity='.65'/><stop offset='1' stop-color='#ffffff' stop-opacity='0'/></linearGradient></defs><rect x='3' y='5' width='42' height='41' rx='12' fill='#111b48'/><rect x='2' y='1' width='44' height='42' rx='12' fill='url(#g)' stroke='#8cedff' stroke-width='1'/><path d='M7 16Q7 5 19 5h13Q39 5 40 11L12 24Z' fill='url(#glass)'/><g transform='translate(0 3)' fill='#713d54' stroke='#38204b' stroke-width='3.4' stroke-linecap='round' stroke-linejoin='round'>"+body+"</g><g fill='url(#gold)' stroke='#fff2aa' stroke-width='1.3' stroke-linecap='round' stroke-linejoin='round'>"+body+"</g><path d='m38 6 1.2 3.5L43 11l-3.8 1.2L38 16l-1.2-3.8L33 11l3.8-1.5Z' fill='#ffffff' fill-opacity='.9'/></svg>"
 var image:=Image.new()
 if image.load_svg_from_string(svg)!=OK:return menu_icon("player")
 _game_covers[index]=ImageTexture.create_from_image(image)
 return _game_covers[index]
