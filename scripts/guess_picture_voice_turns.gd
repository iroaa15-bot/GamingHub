extends Control
## Isolated, editor-only voice-guided turn protocol prototype.
## Does NOT start audio, connect servers, alter game cards or persist scores.
const MAIN := "res://scenes/Main.tscn"
var target_score := 5
var turn_limit := 0
var score := [0, 0]
var asker := 0
var round_number := 1
var turn_left := 0
var pending_guess := false
var finished := false
var timer: Timer
var ui: VBoxContainer
var info: Label
var COLORS := {"bg": Color("#0b1734"), "panel": Color("#1b3158"), "purple": Color("#6753bb"), "green": Color("#208977"), "gold": Color("#f0c568")}

func _ready() -> void:
 if not OS.has_feature("editor"):
  get_tree().change_scene_to_file(MAIN)
  return
 timer = Timer.new()
 timer.wait_time = 1.0
 timer.timeout.connect(_tick)
 add_child(timer)
 _setup()

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

func _setup() -> void:
 timer.stop()
 _layout()
 _label("🎙 خمن صورتك — نظام الأدوار الصوتية", 24)
 _label("محاكاة محلية للأزرار فقط • لا يوجد اتصال صوتي في هذه النسخة", 14)
 _label("نقاط الفوز: " + str(target_score))
 for n in [3, 5, 10, 20]:
  _button(str(n) + " نقاط", func(): target_score = n; _setup(), COLORS["green"] if target_score == n else COLORS["panel"])
 _label("وقت الدور: " + ("بدون وقت" if turn_limit == 0 else str(turn_limit) + " ثانية"))
 for n in [0, 15, 30, 60]:
  _button("بدون وقت" if n == 0 else str(n) + " ثانية", func(): turn_limit = n; _setup(), COLORS["green"] if turn_limit == n else COLORS["panel"])
 _button("ابدأ", _start, COLORS["green"])
 _button("العودة", _home, COLORS["panel"])

func _start() -> void:
 score = [0, 0]
 asker = 0
 round_number = 1
 finished = false
 _turn()

func _turn() -> void:
 if finished:
  return
 timer.stop()
 pending_guess = false
 turn_left = turn_limit
 _layout()
 _label("الجولة " + str(round_number), 25)
 _label("لاعب 1: " + str(score[0]) + "    |    لاعب 2: " + str(score[1]), 18)
 info = _label("دور اللاعب " + str(asker + 1) + " في طرح الأسئلة شفهيًا", 20)
 _label("الطرف الآخر يجيب شفهيًا ويضغط نعم أو لا لتسجيل الرد", 15)
 _button("✅ نعم", func(): _record_response("نعم"), COLORS["green"])
 _button("❌ لا", func(): _record_response("لا"), COLORS["purple"])
 _button("🎯 أريد تأكيد تخمين", _request_guess, COLORS["gold"])
 _button("🔄 تسليم الدور للمنافس", _pass_turn, COLORS["panel"])
 _button("إنهاء المباراة", _finish, COLORS["panel"])
 if turn_limit > 0:
  timer.start()

func _record_response(answer: String) -> void:
 if pending_guess or finished:
  return
 info.text = "رد المنافس: " + answer + " • يقدر اللاعب يكمل الأسئلة أو يسلم الدور"

func _request_guess() -> void:
 if pending_guess or finished:
  return
 pending_guess = true
 timer.stop()
 _layout()
 _label("🎯 تأكيد التخمين", 25)
 _label("اللاعب " + str(asker + 1) + " يقول التخمين بصوته أولًا")
 _label("الطرف الآخر هو الذي يؤكد صحة التخمين — لا يوجد تعرف آلي على الكلام", 15)
 _button("✅ التخمين صحيح — منح نقطة", _confirm_correct, COLORS["green"])
 _button("❌ التخمين خطأ — انتقال الدور", _confirm_wrong, COLORS["purple"])
 _button("إلغاء التأكيد والعودة للدور", _turn, COLORS["panel"])

func _confirm_correct() -> void:
 if not pending_guess or finished:
  return
 pending_guess = false
 score[asker] += 1
 if score[asker] >= target_score:
  _finish()
 else:
  round_number += 1
  asker = (asker + 1) % 2
  _turn()

func _confirm_wrong() -> void:
 if not pending_guess or finished:
  return
 pending_guess = false
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
  info.text = "دور اللاعب " + str(asker + 1) + " • متبقي " + str(turn_left) + " ثانية"

func _finish() -> void:
 finished = true
 timer.stop()
 _layout()
 _label("🏆 نهاية المباراة", 27)
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
