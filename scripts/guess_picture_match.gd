extends Control
## Independent editor-only local match flow. No production networking, voice, ads or saves.
const CATALOG := "res://data/guess_picture_302/catalog.json"
const HOME := "res://scenes/Main.tscn"
const NAVY := Color("#0b1734")
const PANEL := Color("#1c3159")
const PURPLE := Color("#6753bb")
const GOLD := Color("#f0c568")
const GREEN := Color("#218b78")
const RED := Color("#b34358")
var cards: Array = []
var players: Array[String] = []
var points: Array[int] = []
var mode := 0 # 0: local human vs CPU; 1: pass-and-play
var player_count := 2
var target_points := 10
var turn_seconds := 0
var round_number := 0
var active_player := 0
var correct_index := 0
var answered := false
var ended := false
var remaining := 0.0
var turn_timer: Timer
var turn_label: Label
var result_label: Label
var image_rect: TextureRect
var options_box: VBoxContainer
var next_button: Button
var ui: VBoxContainer
var card_order: Array = []
var score_per_correct := 1
var rng := RandomNumberGenerator.new()
var language := "ar"

func tr3(ar: String, en: String, turkish: String) -> String:
 if language == "en":
  return en
 if language == "tr":
  return turkish
 return ar

func _style(c: Color) -> StyleBoxFlat:
 var s := StyleBoxFlat.new()
 s.bg_color = c
 s.set_corner_radius_all(16)
 s.content_margin_left = 12
 s.content_margin_right = 12
 s.content_margin_top = 9
 s.content_margin_bottom = 9
 return s

func add_label(t: String, size: int = 19, tint: Color = Color.WHITE) -> Label:
 var l := Label.new()
 l.text = t
 l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size", size)
 l.add_theme_color_override("font_color", tint)
 ui.add_child(l)
 return l

func add_button(t: String, action: Callable, tint: Color = PURPLE) -> Button:
 var b := Button.new()
 b.text = t
 b.custom_minimum_size.y = 55
 b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 b.add_theme_font_size_override("font_size", 18)
 b.add_theme_stylebox_override("normal", _style(tint))
 b.add_theme_stylebox_override("hover", _style(tint.lightened(0.1)))
 b.add_theme_stylebox_override("pressed", _style(tint.darkened(0.1)))
 b.add_theme_stylebox_override("disabled", _style(PANEL))
 b.add_theme_color_override("font_color", Color.WHITE)
 b.add_theme_color_override("font_disabled_color", Color("#b5bed3"))
 b.pressed.connect(action)
 ui.add_child(b)
 return b

func _ready() -> void:
 if not OS.has_feature("editor"):
  get_tree().change_scene_to_file(HOME)
  return
 language = TranslationServer.get_locale().substr(0, 2)
 rng.randomize()
 if not FileAccess.file_exists(CATALOG):
  _layout()
  add_label(tr3("ملفات الصور غير موجودة في نسخة الاختبار", "Photo catalog is missing", "Fotoğraf kataloğu bulunamadı"))
  add_button(tr3("عودة", "Back", "Geri"), _go_home)
  return
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
 if not data is Dictionary or not data.get("items", null) is Array:
  _layout()
  add_label("Invalid photo catalog")
  add_button("Back", _go_home)
  return
 for item in data["items"]:
  if item is Dictionary and item.get("group", "") == "original_200":
   cards.append(item)
 _show_setup()

func _layout() -> void:
 for child in get_children():
  remove_child(child)
  child.queue_free()
 var bg := ColorRect.new()
 bg.color = NAVY
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(bg)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(scroll)
 var margin := MarginContainer.new()
 margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 margin.add_theme_constant_override("margin_left", 15)
 margin.add_theme_constant_override("margin_right", 15)
 margin.add_theme_constant_override("margin_top", 16)
 margin.add_theme_constant_override("margin_bottom", 20)
 scroll.add_child(margin)
 ui = VBoxContainer.new()
 ui.add_theme_constant_override("separation", 11)
 margin.add_child(ui)

func _show_setup() -> void:
 _layout()
 add_label(tr3("🖼 خمن صورتك", "🖼 Guess Your Picture", "🖼 Resmi Tahmin Et"), 29, GOLD)
 add_label(tr3("إعداد المباراة • اختبار داخلي", "Match setup • internal only", "Maç ayarları • dahili test"), 15)
 add_label(tr3("اختر طريقة اللعب", "Choose match mode", "Oyun modunu seç"), 20)
 add_button(tr3("🤖 ضد الكمبيوتر", "🤖 Versus computer", "🤖 Bilgisayara karşı") + (" ✓" if mode == 0 else ""), func(): mode = 0; _show_setup(), GREEN if mode == 0 else PANEL)
 add_button(tr3("👥 لاعبان إلى 6 على نفس الجهاز", "👥 2–6 players on one device", "👥 Aynı cihazda 2–6 oyuncu") + (" ✓" if mode == 1 else ""), func(): mode = 1; _show_setup(), GREEN if mode == 1 else PANEL)
 if mode == 1:
  add_label(tr3("عدد اللاعبين: ", "Players: ", "Oyuncular: ") + str(player_count), 17)
  add_button("−", func(): player_count = maxi(2, player_count - 1); _show_setup(), PANEL)
  add_button("+", func(): player_count = mini(6, player_count + 1); _show_setup(), PANEL)
 add_label(tr3("هدف الفوز بالنقاط: ", "Points to win: ", "Kazanma puanı: ") + str(target_points), 17)
 add_button("5", func(): target_points = 5; _show_setup(), GREEN if target_points == 5 else PANEL)
 add_button("10", func(): target_points = 10; _show_setup(), GREEN if target_points == 10 else PANEL)
 add_button("20", func(): target_points = 20; _show_setup(), GREEN if target_points == 20 else PANEL)
 add_label(tr3("وقت الإجابة: ", "Answer timer: ", "Cevap süresi: ") + ("∞" if turn_seconds == 0 else str(turn_seconds) + "s"), 17)
 add_button(tr3("بدون مؤقت", "No timer", "Süre yok"), func(): turn_seconds = 0; _show_setup(), GREEN if turn_seconds == 0 else PANEL)
 add_button("15s", func(): turn_seconds = 15; _show_setup(), GREEN if turn_seconds == 15 else PANEL)
 add_button("30s", func(): turn_seconds = 30; _show_setup(), GREEN if turn_seconds == 30 else PANEL)
 add_button("60s", func(): turn_seconds = 60; _show_setup(), GREEN if turn_seconds == 60 else PANEL)
 add_label(tr3("الاتصال: محلي فقط • لا يتم تشغيل ميكروفون أو إرسال رسائل", "Connection: local only • no mic or chat activated", "Bağlantı: yalnızca yerel • mikrofon/sohbet kapalı"), 13, GOLD)
 add_label(tr3("اللعب أونلاين والنص والصوت والنقر: يحتاج ربطًا واختبارًا منفصلين بالسيرفرات الحالية", "Online/text/voice/tap: requires separate integration with existing servers", "Çevrimiçi/ses/metin: ayrı sunucu entegrasyonu gerekli"), 13)
 add_button(tr3("ابدأ المباراة", "Start match", "Maçı başlat"), _start_match, GREEN)
 add_button(tr3("العودة لقائمة الألعاب", "Back to games", "Oyunlara dön"), _go_home, PANEL)

func _start_match() -> void:
 if cards.size() < 4:
  _layout()
  add_label(tr3("عدد الصور غير كافٍ", "Not enough photos", "Yeterli fotoğraf yok"))
  add_button(tr3("عودة", "Back", "Geri"), _show_setup)
  return
 players.clear()
 points.clear()
 players.append(tr3("أنت", "You", "Sen"))
 points.append(0)
 var count := 2 if mode == 0 else player_count
 for i in range(1, count):
  players.append(tr3("الكمبيوتر", "Computer", "Bilgisayar") if mode == 0 else tr3("لاعب ", "Player ", "Oyuncu ") + str(i + 1))
  points.append(0)
 active_player = 0
 round_number = 0
 ended = false
 card_order = cards.duplicate()
 card_order.shuffle()
 _show_turn()

func _card_name(item: Dictionary) -> String:
 var field := "name_en" if language == "en" else ("name_tr" if language == "tr" else "name_ar")
 return str(item.get(field, item.get("name_en", "")))

func _show_turn() -> void:
 if ended:
  return
 if mode == 0 and active_player == 1:
  _cpu_turn()
  return
 if round_number >= card_order.size():
  _end_match(-1)
  return
 answered = false
 _layout()
 var item: Dictionary = card_order[round_number]
 add_label(tr3("الجولة ", "Round ", "Tur ") + str(round_number + 1), 24, GOLD)
 var score_parts: Array[String] = []
 for i in range(players.size()):
  score_parts.append(players[i] + ": " + str(points[i]))
 add_label("   |   ".join(score_parts), 15)
 turn_label = add_label(tr3("دور: ", "Turn: ", "Sıra: ") + players[active_player], 19)
 if turn_seconds > 0:
  remaining = float(turn_seconds)
  turn_label.text += "  ⏱ " + str(turn_seconds)
  turn_timer = Timer.new()
  turn_timer.wait_time = 1.0
  turn_timer.one_shot = false
  turn_timer.timeout.connect(_tick)
  add_child(turn_timer)
  turn_timer.start()
 var frame := PanelContainer.new()
 frame.add_theme_stylebox_override("panel", _style(PANEL))
 ui.add_child(frame)
 image_rect = TextureRect.new()
 image_rect.custom_minimum_size = Vector2(0, 245)
 image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 var image_path := str(item.get("image", ""))
 if ResourceLoader.exists(image_path):
  image_rect.texture = load(image_path) as Texture2D
 frame.add_child(image_rect)
 result_label = add_label(tr3("مين أو إيه اللي في الصورة؟", "Who or what is in the picture?", "Resimde kim veya ne var?"), 19)
 options_box = VBoxContainer.new()
 options_box.add_theme_constant_override("separation", 9)
 ui.add_child(options_box)
 var options: Array = [item]
 var used: Dictionary = {_card_name(item): true}
 var shuffled: Array = cards.duplicate()
 shuffled.shuffle()
 for candidate in shuffled:
  var n := _card_name(candidate)
  if options.size() >= 4:
   break
  if candidate["id"] != item["id"] and not used.has(n):
   options.append(candidate)
   used[n] = true
 options.shuffle()
 for option in options:
  var btn := Button.new()
  btn.text = _card_name(option)
  btn.custom_minimum_size.y = 55
  btn.add_theme_font_size_override("font_size", 18)
  btn.add_theme_stylebox_override("normal", _style(PURPLE))
  btn.add_theme_stylebox_override("disabled", _style(PANEL))
  btn.pressed.connect(_answer.bind(str(option["id"])))
  options_box.add_child(btn)
 next_button = add_button(tr3("تسليم الدور / التالي", "Pass turn / Next", "Sırayı devret / Sonraki"), _advance, GREEN)
 next_button.visible = false
 add_button(tr3("إنهاء المباراة", "End match", "Maçı bitir"), func(): _end_match(-1), PANEL)
 add_label(tr3("اختبار محلي داخل المحرر فقط", "Editor-only local test", "Yalnızca editör testi"), 12, GOLD)

func _tick() -> void:
 if answered or ended:
  if is_instance_valid(turn_timer):
   turn_timer.stop()
  return
 remaining -= 1.0
 if remaining <= 0.0:
  _answer("")
 else:
  turn_label.text = tr3("دور: ", "Turn: ", "Sıra: ") + players[active_player] + " ⏱ " + str(int(remaining))

func _answer(choice: String) -> void:
 if answered or ended:
  return
 answered = true
 if is_instance_valid(turn_timer):
  turn_timer.stop()
 var item: Dictionary = card_order[round_number]
 var correct := choice == str(item["id"])
 if correct:
  points[active_player] += score_per_correct
  result_label.text = tr3("✓ صح! +1 نقطة", "✓ Correct! +1 point", "✓ Doğru! +1 puan")
 else:
  result_label.text = tr3("✗ الإجابة: ", "✗ Answer: ", "✗ Cevap: ") + _card_name(item)
 for child in options_box.get_children():
  if child is Button:
   child.disabled = true
   if child.text == _card_name(item):
    child.add_theme_stylebox_override("disabled", _style(GREEN))
 if points[active_player] >= target_points:
  next_button.text = tr3("عرض النتيجة النهائية", "Show final result", "Sonucu göster")
 next_button.visible = true

func _cpu_turn() -> void:
 if round_number >= card_order.size():
  _end_match(-1)
  return
 # Explicit offline simulation, not remote AI or voice interaction.
 var cpu_correct := rng.randf() < 0.55
 if cpu_correct:
  points[1] += score_per_correct
 _layout()
 add_label(tr3("🤖 دور الكمبيوتر", "🤖 Computer's turn", "🤖 Bilgisayarın sırası"), 26, GOLD)
 add_label(tr3("إجابة صحيحة +1", "Correct +1", "Doğru +1") if cpu_correct else tr3("إجابة خاطئة", "Incorrect", "Yanlış"), 20)
 add_label(players[0] + ": " + str(points[0]) + "   |   " + players[1] + ": " + str(points[1]), 18)
 add_button(tr3("متابعة", "Continue", "Devam"), _advance, GREEN)

func _advance() -> void:
 if ended:
  return
 if points[active_player] >= target_points:
  _end_match(active_player)
  return
 active_player = (active_player + 1) % players.size()
 round_number += 1
 _show_turn()

func _end_match(winner: int) -> void:
 ended = true
 if is_instance_valid(turn_timer):
  turn_timer.stop()
 _layout()
 add_label(tr3("🏆 نهاية المباراة", "🏆 Match finished", "🏆 Maç bitti"), 28, GOLD)
 var best := -1
 for i in range(points.size()):
  best = maxi(best, points[i])
 var winners: Array[String] = []
 for i in range(points.size()):
  add_label(players[i] + ": " + str(points[i]), 19)
  if points[i] == best:
   winners.append(players[i])
 add_label(tr3("الفائز: ", "Winner: ", "Kazanan: ") + (players[winner] if winner >= 0 else " / ".join(winners)), 22, GREEN)
 add_button(tr3("المرحلة التالية / مباراة جديدة", "Next stage / New match", "Sonraki aşama / Yeni maç"), _start_match, GREEN)
 add_button(tr3("تعديل الإعدادات", "Change settings", "Ayarları değiştir"), _show_setup, PURPLE)
 add_button(tr3("العودة للقائمة", "Back to games", "Oyunlara dön"), _go_home, PANEL)

func _go_home() -> void:
 get_tree().change_scene_to_file(HOME)
