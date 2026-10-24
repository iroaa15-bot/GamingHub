extends Control
## Isolated editor-only photo game. Does not change multiplayer, audio, ads or main menu.
const CATALOG_PATH := "res://data/guess_picture_302/catalog.json"
const NAVY := Color("#0b1734")
const CARD := Color("#172a51")
const PURPLE := Color("#6652bd")
const GOLD := Color("#f0c568")
const WHITE := Color("#f5f6ff")
const GREEN := Color("#248e7e")
const RED := Color("#ad4057")
var items: Array = []
var pool: Array = []
var index := 0
var score := 0
var answered := false
var include_review := false
var photo: TextureRect
var status_label: Label
var answer_label: Label
var options_box: VBoxContainer
var next_button: Button
var answer_buttons: Array[Button] = []

func _t(ar: String, en: String, tr: String) -> String:
 var lang := TranslationServer.get_locale().substr(0, 2)
 if lang == "tr":
  return tr
 return en if lang == "en" else ar

func _panel(color: Color, radius: int = 18) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = color
 style.set_corner_radius_all(radius)
 style.content_margin_left = 12.0
 style.content_margin_right = 12.0
 style.content_margin_top = 10.0
 style.content_margin_bottom = 10.0
 return style

func _style_button(button: Button, color: Color = PURPLE) -> void:
 button.custom_minimum_size.y = 54
 button.add_theme_font_size_override("font_size", 19)
 button.add_theme_color_override("font_color", WHITE)
 button.add_theme_color_override("font_hover_color", WHITE)
 button.add_theme_color_override("font_pressed_color", WHITE)
 button.add_theme_stylebox_override("normal", _panel(color))
 button.add_theme_stylebox_override("hover", _panel(color.lightened(0.12)))
 button.add_theme_stylebox_override("pressed", _panel(color.darkened(0.12)))
 button.add_theme_stylebox_override("disabled", _panel(CARD))
 button.focus_mode = Control.FOCUS_NONE

func _label(text_value: String, font_size: int, color: Color = WHITE) -> Label:
 var result := Label.new()
 result.text = text_value
 result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 result.add_theme_font_size_override("font_size", font_size)
 result.add_theme_color_override("font_color", color)
 return result

func _ready() -> void:
 if not OS.has_feature("editor"):
  get_tree().change_scene_to_file("res://scenes/Main.tscn")
  return
 if not FileAccess.file_exists(CATALOG_PATH):
  push_error("Photo preview catalog missing")
  return
 var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
 if not raw is Dictionary or not raw.has("items") or not raw["items"] is Array:
  push_error("Invalid photo preview catalog")
  return
 items = raw["items"]
 _build_ui()
 _refresh_pool()

func _build_ui() -> void:
 var background := ColorRect.new()
 background.color = NAVY
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(background)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(scroll)
 var margin := MarginContainer.new()
 margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 margin.add_theme_constant_override("margin_left", 15)
 margin.add_theme_constant_override("margin_right", 15)
 margin.add_theme_constant_override("margin_top", 18)
 margin.add_theme_constant_override("margin_bottom", 18)
 scroll.add_child(margin)
 var root := VBoxContainer.new()
 root.add_theme_constant_override("separation", 12)
 root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 margin.add_child(root)
 root.add_child(_label(_t("🖼 خمن صورتك", "🖼 Guess Your Picture", "🖼 Resmi Tahmin Et"), 28, GOLD))
 root.add_child(_label(_t("مكتبة الصور • اختبار داخلي", "Photo library • internal test", "Fotoğraf arşivi • dahili test"), 14))
 var toggle := CheckButton.new()
 toggle.text = _t("تضمين 102 صورة قيد مراجعة الحقوق", "Include 102 rights-review images", "Hakları incelenen 102 resmi dahil et")
 toggle.add_theme_font_size_override("font_size", 13)
 toggle.toggled.connect(_toggle_review)
 root.add_child(toggle)
 status_label = _label("", 17, GOLD)
 root.add_child(status_label)
 var image_panel := PanelContainer.new()
 image_panel.add_theme_stylebox_override("panel", _panel(CARD, 22))
 root.add_child(image_panel)
 photo = TextureRect.new()
 photo.custom_minimum_size = Vector2(0, 260)
 photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image_panel.add_child(photo)
 answer_label = _label(_t("مين أو إيه اللي في الصورة؟", "Who or what is in the picture?", "Resimde kim veya ne var?"), 19)
 root.add_child(answer_label)
 options_box = VBoxContainer.new()
 options_box.add_theme_constant_override("separation", 9)
 root.add_child(options_box)
 next_button = Button.new()
 next_button.text = _t("التالي ←", "Next →", "Sonraki →")
 _style_button(next_button, GREEN)
 next_button.pressed.connect(_next)
 root.add_child(next_button)
 var back := Button.new()
 back.text = _t("العودة إلى Gaming Hub", "Back to Gaming Hub", "Gaming Hub'a dön")
 _style_button(back, CARD)
 back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
 root.add_child(back)
 root.add_child(_label(_t("للاختبار داخل Godot فقط — غير معتمد للنشر", "Godot editor test only — not cleared for release", "Yalnızca Godot testi — yayına uygun değil"), 12, GOLD))

func _toggle_review(value: bool) -> void:
 include_review = value
 _refresh_pool()

func _refresh_pool() -> void:
 pool.clear()
 for item in items:
  if item is Dictionary and (item.get("group", "") == "original_200" or include_review):
   pool.append(item)
 index = 0
 score = 0
 _show_card()

func _next() -> void:
 if not pool.is_empty():
  index = (index + 1) % pool.size()
  _show_card()

func _name(item: Dictionary) -> String:
 var lang := TranslationServer.get_locale().substr(0, 2)
 var key := "name_en" if lang == "en" else ("name_tr" if lang == "tr" else "name_ar")
 return str(item.get(key, item.get("name_en", "")))

func _show_card() -> void:
 if pool.is_empty():
  answer_label.text = _t("لا توجد صور متاحة", "No images available", "Resim bulunamadı")
  return
 answered = false
 var item: Dictionary = pool[index]
 var path := str(item.get("image", ""))
 photo.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
 status_label.text = _t("الصورة %d / %d  •  النقاط %d", "Picture %d / %d  •  Score %d", "Resim %d / %d  •  Puan %d") % [index + 1, pool.size(), score]
 answer_label.text = _t("مين أو إيه اللي في الصورة؟", "Who or what is in the picture?", "Resimde kim veya ne var?")
 for child in options_box.get_children():
  options_box.remove_child(child)
  child.queue_free()
 answer_buttons.clear()
 var options: Array = [item]
 var candidates: Array = pool.duplicate()
 candidates.shuffle()
 var used_names: Dictionary = {_name(item): true}
 for candidate in candidates:
  if options.size() >= 4:
   break
  var candidate_name := _name(candidate)
  if candidate["id"] != item["id"] and not used_names.has(candidate_name):
   options.append(candidate)
   used_names[candidate_name] = true
 options.shuffle()
 for option in options:
  var button := Button.new()
  button.text = _name(option)
  _style_button(button)
  button.pressed.connect(_answer.bind(str(option["id"]), button))
  options_box.add_child(button)
  answer_buttons.append(button)

func _answer(id: String, selected_button: Button) -> void:
 if answered or pool.is_empty():
  return
 answered = true
 var item: Dictionary = pool[index]
 var correct := id == str(item["id"])
 if correct:
  score += 1
  answer_label.text = _t("✓ إجابة صحيحة!", "✓ Correct!", "✓ Doğru!")
 else:
  answer_label.text = _t("الإجابة الصحيحة: ", "Correct answer: ", "Doğru cevap: ") + _name(item)
 for button in answer_buttons:
  if button.text == _name(item):
   _style_button(button, GREEN)
  elif button == selected_button:
   _style_button(button, RED)
  button.disabled = true
 status_label.text = _t("الصورة %d / %d  •  النقاط %d", "Picture %d / %d  •  Score %d", "Resim %d / %d  •  Puan %d") % [index + 1, pool.size(), score]
