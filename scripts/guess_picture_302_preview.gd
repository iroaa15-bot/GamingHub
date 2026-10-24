extends Control
## Editor-only internal preview. Never enable unlicensed photos in release builds.
const CATALOG_PATH := "res://data/guess_picture_302/catalog.json"
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

func _ready() -> void:
 if not OS.has_feature("editor"):
  get_tree().change_scene_to_file("res://scenes/Main.tscn")
  return
 var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
 if not raw is Dictionary or not raw.has("items"):
  push_error("Missing photo preview catalog")
  return
 items = raw["items"]
 _build_ui()
 _refresh_pool()

func _build_ui() -> void:
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(scroll)
 var root := VBoxContainer.new()
 root.custom_minimum_size = Vector2(340, 0)
 root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(root)
 var title := Label.new()
 title.text = "خمن صورتك | معاينة 302 صورة"
 root.add_child(title)
 var note := Label.new()
 note.text = "للاختبار داخل المحرر فقط — الصور ليست مرخصة للنشر"
 root.add_child(note)
 var toggle := CheckButton.new()
 toggle.text = "تضمين 102 صورة قيد مراجعة الحقوق"
 toggle.toggled.connect(_toggle_review)
 root.add_child(toggle)
 status_label = Label.new()
 root.add_child(status_label)
 photo = TextureRect.new()
 photo.custom_minimum_size = Vector2(320, 290)
 photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 root.add_child(photo)
 answer_label = Label.new()
 root.add_child(answer_label)
 options_box = VBoxContainer.new()
 root.add_child(options_box)
 var back := Button.new()
 back.text = "العودة إلى Gaming Hub"
 back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
 root.add_child(back)
 var next := Button.new()
 next.text = "التالي"
 next.pressed.connect(_next)
 root.add_child(next)

func _toggle_review(value: bool) -> void:
 include_review = value
 _refresh_pool()

func _refresh_pool() -> void:
 pool.clear()
 for item in items:
  if item.get("group", "") == "original_200" or include_review:
   pool.append(item)
 index = 0
 score = 0
 _show_card()

func _next() -> void:
 if not pool.is_empty():
  index = (index + 1) % pool.size()
  _show_card()

func _show_card() -> void:
 if pool.is_empty():
  return
 answered = false
 var item: Dictionary = pool[index]
 photo.texture = load(str(item["image"])) as Texture2D
 status_label.text = "%d / %d | نقاط: %d" % [index + 1, pool.size(), score]
 answer_label.text = "مين أو إيه اللي في الصورة؟"
 for child in options_box.get_children():
  options_box.remove_child(child)
  child.queue_free()
 var options: Array = [item]
 var candidates: Array = pool.duplicate()
 candidates.shuffle()
 for candidate in candidates:
  if candidate["id"] != item["id"] and options.size() < 4:
   options.append(candidate)
 options.shuffle()
 for option in options:
  var b := Button.new()
  b.text = str(option.get("name_ar", option.get("name_en", "")))
  b.pressed.connect(_answer.bind(str(option["id"])))
  options_box.add_child(b)

func _answer(id: String) -> void:
 if answered or pool.is_empty():
  return
 answered = true
 var item: Dictionary = pool[index]
 if id == str(item["id"]):
  score += 1
  answer_label.text = "صح!"
 else:
  answer_label.text = "الإجابة: " + str(item.get("name_ar", item.get("name_en", "")))
 status_label.text = "%d / %d | نقاط: %d" % [index + 1, pool.size(), score]
