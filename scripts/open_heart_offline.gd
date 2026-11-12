extends Control
## Complete local pass-and-play flow for Open Heart; no online dependency.
const PartyEngine = preload("res://scripts/qaadet_el_sohab_engine.gd")
const PATHS = ["res://content/qaadet_el_sohab/seed_ar.json", "res://content/qaadet_el_sohab/seed_ar_batch02.json"]

static func _batch_paths() -> Array[String]:
	var result: Array[String] = []
	for i in range(1, 11):
		result.append("res://content/qaadet_el_sohab/open_heart_batch_%02d.json" % i)
	return result
var engine: QaadetElSohabEngine = PartyEngine.new()
var names_input: LineEdit
var rounds_input: OptionButton
var panel: VBoxContainer
var feedback: Label
var all_cards: Array[Dictionary] = []
var finished := false
var match_started := false

func _ready() -> void:
	all_cards = _load_cards()
	_render_setup()

func _load_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var ids := {}
	for path in PATHS + _batch_paths():
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary or not parsed.get("cards", null) is Array:
			continue
		for item in parsed["cards"]:
			if item is Dictionary and str(item.get("category", "")) == "open_heart":
				var id := str(item.get("id", ""))
				if not id.is_empty() and not ids.has(id) and not str(item.get("text_ar", "")).is_empty():
					ids[id] = true
					cards.append(item)
	return cards

func _layout(title: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var backdrop = load("res://scripts/social_game_backdrop.gd").new()
	add_child(backdrop)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 20)
	scroll.add_child(panel)
	_text(title, 34)
	feedback = _text("", 20)

func _text(value: String, size: int = 24) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	panel.add_child(label)
	return label

func _button(value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 72
	button.pressed.connect(callback)
	panel.add_child(button)

func _render_setup() -> void:
	match_started = false
	_layout("افتح قلبك")
	_text("كل لاعب يجاوب على كارت في دوره. المشاركة = 10 نقاط، والتخطي بدون خصم. تقدر تتخطى أي سؤال مش مرتاح له.", 20)
	_text("اكتب أسماء اللاعبين مفصولة بفاصلة (من 2 إلى 6)", 19)
	names_input = LineEdit.new()
	names_input.placeholder_text = "أحمد، سارة، منى"
	names_input.text = "لاعب 1، لاعب 2، لاعب 3"
	panel.add_child(names_input)
	_text("عدد الجولات", 20)
	rounds_input = OptionButton.new()
	for number in [10, 15, 20]:
		rounds_input.add_item(str(number), number)
	panel.add_child(rounds_input)
	_text("الكروت المتاحة حاليًا: %d" % all_cards.size(), 16)
	_button("ابدأ اللعب", _start)
	_button("رجوع", _back)

func _start() -> void:
	var names: Array[String] = []
	for raw in names_input.text.replace("،", ",").split(","):
		var name := raw.strip_edges()
		if not name.is_empty():
			names.append(name)
	if names.size() < 2 or names.size() > 6 or names.size() != _distinct_count(names):
		feedback.text = "اكتب من 2 إلى 6 أسماء مختلفة."
		return
	var rounds := rounds_input.get_item_id(rounds_input.selected)
	if all_cards.size() < rounds:
		feedback.text = "الكروت الحالية أقل من عدد الجولات. اختار عددًا أقل."
		return
	if not engine.setup(names, all_cards, rounds) or not engine.lock_category("open_heart"):
		feedback.text = "تعذر تجهيز المباراة."
		return
	finished = false
	match_started = true
	_next()

func _distinct_count(values: Array[String]) -> int:
	var seen := {}
	for value in values:
		seen[value.to_lower()] = true
	return seen.size()

func _next() -> void:
	if engine.round_index >= engine.round_limit:
		_render_results()
		return
	var card: Dictionary = engine.draw_next("open_heart")
	if card.is_empty():
		_render_results()
		return
	_layout("افتح قلبك — الجولة %d من %d" % [engine.round_index + 1, engine.round_limit])
	_text("الدور على: %s" % engine.players[engine.active_player_index])
	_text(str(card.get("text_ar", "")), 29)
	_text("مسموح تتخطى السؤال من غير أي عقوبة.", 18)
	_button("جاوبت — +10 نقاط", func(): _complete(true))
	_button("تخطي السؤال — بدون نقاط", func(): _complete(false))
	_button("إنهاء المباراة", _render_results)

func _complete(participated: bool) -> void:
	var result: Dictionary = engine.resolve_round(participated)
	if result.is_empty():
		feedback.text = "تعذر إنهاء الجولة."
		return
	if bool(result.get("finished", false)):
		_render_results()
	else:
		_next()

func _render_results() -> void:
	if not match_started:
		_render_setup()
		return
	_layout("النتيجة الحالية — افتح قلبك")
	var ranking := engine.players.duplicate()
	ranking.sort_custom(func(a, b): return int(engine.scores[a]) > int(engine.scores[b]))
	for i in range(ranking.size()):
		_text("%d. %s — %d نقطة" % [i + 1, ranking[i], int(engine.scores[ranking[i]])], 23)
	if not engine.current_card.is_empty():
		_text("الجولة المفتوحة لم تُحسب.", 17)
	if engine.round_index < engine.round_limit:
		_button("استكمال المباراة", _resume)
	_button("مباراة جديدة", _render_setup)
	_button("رجوع لقائمة اللعبة", _back)

func _resume() -> void:
	if not engine.current_card.is_empty():
		_show_existing()
	else:
		_next()

func _show_existing() -> void:
	_layout("افتح قلبك — الجولة %d من %d" % [engine.round_index + 1, engine.round_limit])
	_text("الدور على: %s" % engine.players[engine.active_player_index])
	_text(str(engine.current_card.get("text_ar", "")), 29)
	_button("جاوبت — +10 نقاط", func(): _complete(true))
	_button("تخطي السؤال — بدون نقاط", func(): _complete(false))
	_button("النتيجة الحالية", _render_results)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/OpenHeartMode.tscn")
