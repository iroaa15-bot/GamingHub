extends Control
## Isolated, editor-only three-mode question flow prototype.
## Does NOT start audio, connect servers, alter game cards or persist scores.
const MAIN := "res://scenes/Main.tscn"
const CATALOG := "res://data/guess_picture_302/catalog.json"
# Only catalog facts with explicit boolean values can drive automatic yes/no.
const FACT_QUESTIONS := {"living": "هل هو كائن حي؟", "animal": "هل هو حيوان؟", "celebrity": "هل هو شخص مشهور؟", "household": "هل يُستخدم في المنزل؟", "edible": "هل يمكن أكله؟", "natural": "هل يوجد في الطبيعة؟", "place": "هل هو مكان؟", "large": "هل حجمه كبير؟"}
var photo_items: Array = []
var active_photo: Dictionary = {}
var question_mode := "all" # approved default: voice + text + prepared tap questions
var play_mode := "friends" # local two-friend protocol prototype; online room not connected
var question_input: LineEdit
var guess_input: LineEdit
var last_question := ""
const READY_QUESTIONS := ["هل هو كائن حي؟", "هل هو حيوان؟", "هل هو شخص مشهور؟", "هل يُستخدم في المنزل؟", "هل يمكن أكله؟", "هل يوجد في الطبيعة؟", "هل هو مكان؟", "هل حجمه كبير؟"]
var target_score := 10
var score_per_win := 1
var turn_limit := 30
var score := [0, 0]
var asker := 0
var round_number := 1
var turn_left := 0
var pending_guess := false
var finished := false
var timer: Timer
var ui: VBoxContainer
var info: Label
var clock_label: Label
var clock_bar: ProgressBar
var history_label: Label
var event_history: Array[String] = []
var COLORS := {"bg": Color("#0b1734"), "panel": Color("#1b3158"), "purple": Color("#6753bb"), "green": Color("#208977"), "gold": Color("#f0c568")}

func _ready() -> void:
 if not OS.has_feature("editor"):
  get_tree().change_scene_to_file(MAIN)
  return
 timer = Timer.new()
 timer.wait_time = 1.0
 timer.timeout.connect(_tick)
 add_child(timer)
 _load_photo_facts()
 _setup()

func _load_photo_facts() -> void:
 photo_items.clear()
 if not FileAccess.file_exists(CATALOG):
  return
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
 if parsed is Dictionary and parsed.get("items") is Array:
  for item in parsed["items"]:
   if item is Dictionary and item.get("group", "") == "original_200":
    photo_items.append(item)

func _next_photo() -> void:
 active_photo = {}
 if not photo_items.is_empty():
  active_photo = photo_items.pick_random()

func _layout() -> void:
 for node in get_children():
  if node != timer:
   remove_child(node)
   node.queue_free()
 var bg := ColorRect.new()
 bg.color = COLORS["bg"]
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(bg)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(scroll)
 var margin := MarginContainer.new()
 margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
 for side in ["left", "right", "top", "bottom"]:
  margin.add_theme_constant_override("margin_" + side, 16)
 scroll.add_child(margin)
 ui = VBoxContainer.new()
 ui.add_theme_constant_override("separation", 12)
 margin.add_child(ui)

func _label(t: String, size: int = 19) -> Label:
 var l := Label.new()
 l.text = t
 l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size", size)
 l.add_theme_color_override("font_color", Color.WHITE)
 ui.add_child(l)
 return l

func _button(t: String, action: Callable, color: Color) -> Button:
 var b := Button.new()
 b.text = t
 b.custom_minimum_size.y = 57
 b.add_theme_font_size_override("font_size", 18)
 b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var s := StyleBoxFlat.new()
 s.bg_color = color
 s.set_corner_radius_all(16)
 s.content_margin_top = 8
 s.content_margin_bottom = 8
 b.add_theme_stylebox_override("normal", s)
 b.add_theme_stylebox_override("hover", s)
 b.pressed.connect(action)
 ui.add_child(b)
 return b

func _panel(text_value: String, background_color: Color, size: int = 19) -> void:
 var frame := PanelContainer.new()
 var style := StyleBoxFlat.new()
 style.bg_color = background_color
 style.set_corner_radius_all(18)
 style.set_content_margin_all(16)
 frame.add_theme_stylebox_override("panel", style)
 ui.add_child(frame)
 var title := Label.new()
 title.text = text_value
 title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title.add_theme_color_override("font_color", Color.WHITE)
 title.add_theme_font_size_override("font_size", size)
 frame.add_child(title)

func _log_event(value: String) -> void:
 event_history.append(value)
 if event_history.size() > 6:
  event_history.pop_front()
 if is_instance_valid(history_label):
  history_label.text = "\n".join(event_history)

func _scoreboard() -> void:
 var leader := "تعادل" if score[0] == score[1] else ("لاعب 1 متقدم" if score[0] > score[1] else "لاعب 2 متقدم")
 _panel("🏆  " + str(score[0]) + "  ━  " + str(score[1]) + "  |  الهدف " + str(target_score) + "\n" + leader, COLORS["panel"], 23)
 _panel("الجولة " + str(round_number) + "  •  الدور: اللاعب " + str(asker + 1), COLORS["purple"], 18)

func _clock() -> void:
 if turn_limit == 0:
  _panel("⏱ وقت مفتوح", COLORS["panel"], 17)
  return
 clock_label = _label("⏱ " + str(turn_left) + " ثانية", 19)
 clock_bar = ProgressBar.new()
 clock_bar.custom_minimum_size.y = 12
 clock_bar.show_percentage = false
 clock_bar.max_value = turn_limit
 clock_bar.value = turn_left
 ui.add_child(clock_bar)

func _history() -> void:
 _label("آخر أحداث المباراة", 17)
 history_label = _label("لا توجد أسئلة بعد" if event_history.is_empty() else "\n".join(event_history), 14)

func _setup() -> void:
 timer.stop()
 _layout()
 _panel("🖼️ خمن صورتك\nPHOTO DUEL", COLORS["purple"], 28)
 _label("أصدقاء • أسئلة شفوية ونصية وجاهزة", 16)
 _label("اختبار على جهاز واحد فقط؛ الصوت والشات الشبكي لم يتم ربطهما بعد", 14)
 _label("طريقة اللعب: أصدقاء (لاعبان في النموذج المحلي)", 18)
 _label("طريقة السؤال (يمكن الجمع بين الثلاثة):", 19)
 for key in ["voice", "text", "tap", "all"]:
  var names := {"voice": "🎙 شفهي", "text": "💬 نصي", "tap": "👆 أسئلة جاهزة", "all": "✨ الثلاثة معًا"}
  _button(names[key] + (" ✓" if question_mode == key else ""), func(): question_mode = key; _setup(), COLORS["green"] if question_mode == key else COLORS["panel"])
 _label("نقاط الفوز: " + str(target_score))
 for n in [3, 5, 10, 15, 20, 30, 50]:
  _button(str(n) + " نقاط", func(): target_score = n; _setup(), COLORS["green"] if target_score == n else COLORS["panel"])
 _label("وقت الدور: " + ("بدون وقت" if turn_limit == 0 else str(turn_limit) + " ثانية"))
 for n in [0, 10, 20, 30, 60]:
  _button("بدون وقت" if n == 0 else str(n) + " ثانية", func(): turn_limit = n; _setup(), COLORS["green"] if turn_limit == n else COLORS["panel"])
 _label("نقاط التخمين الصحيح: " + str(score_per_win), 17)
 for n in [1, 2, 3, 5]:
  _button("+" + str(n), func(): score_per_win = n; _setup(), COLORS["green"] if score_per_win == n else COLORS["panel"])
 _button("ابدأ", _start, COLORS["green"])
 _button("العودة", _home, COLORS["panel"])

func _start() -> void:
 score = [0, 0]
 asker = 0
 round_number = 1
 finished = false
 event_history.clear()
 _next_photo()
 _turn()

func _turn() -> void:
 if finished:
  return
 timer.stop()
 pending_guess = false
 turn_left = turn_limit
 _layout()
 clock_label = null
 clock_bar = null
 history_label = null
 _panel("PHOTO DUEL  •  خمن صورتك", COLORS["purple"], 25)
 _scoreboard()
 _clock()
 if not active_photo.is_empty():
  var image_path := str(active_photo.get("image", ""))
  if ResourceLoader.exists(image_path):
   var picture := TextureRect.new()
   picture.texture = load(image_path) as Texture2D
   picture.custom_minimum_size = Vector2(0, 220)
   picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
   ui.add_child(picture)
 _panel("🖼️ صورة الجولة — العرض المحلي فقط", COLORS["panel"], 16)
 info = _label("دور اللاعب " + str(asker + 1) + " في طرح السؤال", 20)
 if question_mode in ["voice", "all"]:
  _panel("🎙️ السؤال الشفهي متاح وجهًا لوجه فقط\nالصوت الشبكي غير متصل بهذا النموذج", COLORS["panel"], 15)
 if question_mode in ["text", "all"]:
  question_input = LineEdit.new()
  question_input.placeholder_text = "اكتب سؤالك هنا (عرض محلي فقط)"
  ui.add_child(question_input)
  _button("💬 إرسال السؤال داخل شاشة الاختبار", _submit_text_question, COLORS["panel"])
 if question_mode in ["tap", "all"]:
  _label("👆 اختر سؤالًا جاهزًا", 16)
  var facts: Variant = active_photo.get("facts", {})
  if facts is Dictionary:
   for key in FACT_QUESTIONS:
    if facts.get(key) is bool:
     _button(FACT_QUESTIONS[key], _select_fact_question.bind(key), COLORS["panel"])
  _label("الأسئلة التلقائية تظهر فقط للصور التي لها بيانات نعم/لا موثقة في الكتالوج", 14)
 _label("الطرف الآخر يرد بنعم أو لا؛ السؤال والإجابة لا يمنحان نقاطًا", 15)
 _button("✅ نعم", func(): _record_response("نعم"), COLORS["green"])
 _button("❌ لا", func(): _record_response("لا"), COLORS["purple"])
 _button("🎯 أريد تأكيد تخمين", _request_guess, COLORS["gold"])
 _button("🔄 تسليم الدور للمنافس", _pass_turn, COLORS["panel"])
 _history()
 _button("إنهاء المباراة", _finish, COLORS["panel"])
 if turn_limit > 0:
  timer.start()

func _submit_text_question() -> void:
 if question_input == null or pending_guess or finished:
  return
 var value := question_input.text.strip_edges()
 if value.is_empty():
  return
 last_question = value
 info.text = "السؤال النصي المحلي: " + value
 _log_event("💬 لاعب " + str(asker + 1) + ": " + value)
 question_input.clear()

func _select_fact_question(key: String) -> void:
 if pending_guess or finished:
  return
 var facts: Variant = active_photo.get("facts", {})
 if not facts is Dictionary or not facts.get(key) is bool:
  return
 last_question = FACT_QUESTIONS[key]
 info.text = last_question + " — " + ("نعم ✅" if facts[key] else "لا ❌")
 _log_event("👆 " + last_question + " → " + ("نعم" if facts[key] else "لا"))

func _record_response(answer: String) -> void:
 if pending_guess or finished:
  return
 info.text = "رد المنافس: " + answer + " • يقدر اللاعب يكمل الأسئلة أو يسلم الدور"
 _log_event("🗣️ المنافس: " + answer)

func _request_guess() -> void:
 if pending_guess or finished:
  return
 pending_guess = true
 timer.stop()
 _layout()
 _label("🎯 تأكيد التخمين", 25)
 _label("اللاعب " + str(asker + 1) + " يعلن التخمين شفهيًا أو كتابيًا", 17)
 guess_input = LineEdit.new()
 guess_input.placeholder_text = "التخمين النصي اختياري (محلي فقط)"
 ui.add_child(guess_input)
 _label("الطرف الآخر يؤكد صحة التخمين يدويًا — لا يوجد تعرف آلي على الكلام", 15)
 _label("التخمين الصحيح يمنح " + str(score_per_win) + " نقطة؛ والخاطئ ينقل الدور", 14)
 _button("✅ التخمين صحيح — منح نقطة", _confirm_correct, COLORS["green"])
 _button("❌ التخمين خطأ — انتقال الدور", _confirm_wrong, COLORS["purple"])
 _button("إلغاء التأكيد والعودة للدور", _turn, COLORS["panel"])

func _confirm_correct() -> void:
 if not pending_guess or finished:
  return
 pending_guess = false
 score[asker] += score_per_win
 _log_event("🎯 تخمين صحيح للاعب " + str(asker + 1) + "  +" + str(score_per_win))
 if score[asker] >= target_score:
  _finish()
 else:
  round_number += 1
  _next_photo()
  asker = (asker + 1) % 2
  _turn()

func _confirm_wrong() -> void:
 if not pending_guess or finished:
  return
 pending_guess = false
 _log_event("❌ تخمين غير صحيح — انتقال الدور")
 _pass_turn()

func _pass_turn() -> void:
 if finished:
  return
 timer.stop()
 asker = (asker + 1) % 2
 _turn()

func _tick() -> void:
 if finished or pending_guess:
  timer.stop()
  return
 turn_left -= 1
 if turn_left <= 0:
  _pass_turn()
 else:
  if is_instance_valid(clock_label):
   clock_label.text = "⏱ " + str(turn_left) + " ثانية"
  if is_instance_valid(clock_bar):
   clock_bar.value = turn_left
  if is_instance_valid(info):
   info.text = "دور اللاعب " + str(asker + 1) + " • متبقي " + str(turn_left) + " ثانية"

func _finish() -> void:
 finished = true
 timer.stop()
 _layout()
 _panel("🏆 نهاية المباراة", COLORS["purple"], 27)
 _label("الهدف: " + str(target_score) + " نقاط", 16)
 _label("لاعب 1: " + str(score[0]) + "    |    لاعب 2: " + str(score[1]))
 if score[0] == score[1]:
  _label("تعادل")
 else:
  _label("الفائز: اللاعب " + str(1 if score[0] > score[1] else 2))
 _button("المرحلة التالية — مباراة جديدة", _start, COLORS["green"])
 _button("تعديل الإعدادات", _setup, COLORS["purple"])
 _button("العودة", _home, COLORS["panel"])

func _home() -> void:
 get_tree().change_scene_to_file(MAIN)
