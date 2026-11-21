extends RefCounted
## A compact, fully tappable catalog card using the game's existing artwork.
## The caller keeps ownership of ordering, visibility and the actual route.
const TileSkin = preload("res://scripts/visual_skin.gd")
const FILLS = ["0056a8", "ad192e", "12823a", "6914a0", "bd6b08", "b52a27", "123cac", "871b77", "09638e", "b94e0b"]
const EDGES = ["5ae5ff", "ff8594", "91f18d", "e891ff", "ffd66b", "ffc0a0", "8abaff", "ff9ce7", "81eaff", "ffd18b"]

static func make(main: Control, index: int, art_id: String, favorite: bool) -> PanelContainer:
 var tile := PanelContainer.new()
 tile.name = "ReferenceGameTile"
 tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var empty := StyleBoxEmpty.new()
 tile.add_theme_stylebox_override("panel", empty)
 var title: String = ("★ " if favorite else "") + main.game_title(index)
 var action: Button = main.button(title, func(): main.show_modes(index), main.PANEL)
 action.reparent(tile)
 action.name = "GameAction"
 action.set_meta("reference_game_tile", true)
 action.tooltip_text = main.game_subtitle(index)
 action.custom_minimum_size = Vector2(0, 140 if main.reading_scale >= 1.25 else 112)
 action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var fill := Color(FILLS[index % FILLS.size()])
 var edge := Color(EDGES[index % EDGES.size()])
 action.add_theme_stylebox_override("normal", TileSkin.neon_surface(fill, edge))
 action.add_theme_stylebox_override("hover", TileSkin.neon_surface(fill.lightened(0.08), edge.lightened(0.08)))
 action.add_theme_stylebox_override("pressed", TileSkin.neon_surface(fill.darkened(0.2), edge))
 action.add_theme_stylebox_override("disabled", TileSkin.neon_surface(Color("18234b"), Color("33436c")))
 var focus := StyleBoxFlat.new()
 focus.draw_center = false; focus.border_color = Color("ffffff"); focus.set_border_width_all(2); focus.set_corner_radius_all(15)
 action.add_theme_stylebox_override("focus", focus)
 # Keep the button text available to accessibility while the centred label
 # renders over the artwork without obscuring either of them.
 for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
  action.add_theme_color_override(state, Color.TRANSPARENT)
 var column := VBoxContainer.new()
 column.name = "Content"
 column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 column.offset_left = 5; column.offset_right = -5; column.offset_top = 5; column.offset_bottom = -5
 column.add_theme_constant_override("separation", 1)
 column.mouse_filter = Control.MOUSE_FILTER_IGNORE
 action.add_child(column)
 var art := TextureRect.new()
 var cover: Texture2D = TileSkin.game_cover(index)
 art.texture = cover if cover != null else main.card_texture(art_id)
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.size_flags_vertical = Control.SIZE_EXPAND_FILL
 art.custom_minimum_size.y = 50
 art.mouse_filter = Control.MOUSE_FILTER_IGNORE
 column.add_child(art)
 var caption := Label.new()
 caption.name = "Caption"
 caption.text = title
 caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 caption.add_theme_font_size_override("font_size", int(14 * main.reading_scale))
 caption.add_theme_color_override("font_color", Color.WHITE)
 caption.add_theme_color_override("font_shadow_color", Color("061033"))
 caption.add_theme_constant_override("shadow_offset_y", 2)
 caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
 column.add_child(caption)
 return tile
