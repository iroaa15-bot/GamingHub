extends Control
## Pass-and-play acting game; no server or online claim.
const PartyEngine = preload("res://scripts/qaadet_el_sohab_engine.gd")
const SEEDS = ["res://content/qaadet_el_sohab/seed_ar.json", "res://content/qaadet_el_sohab/seed_ar_batch02.json"]
var engine: QaadetElSohabEngine = PartyEngine.new()
var cards: Array[Dictionary] = []
var panel: VBoxContainer
var status: Label
var names_input: LineEdit
var rounds_input: OptionButton
var seconds_left := 30
var timer: Timer
var voting := false
var match_started := false

func _ready() -> void:
	cards = _load_cards()
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_tick)
	add_child(timer)
	_setup_screen()

func _load_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	var paths := SEEDS.duplicate()
	for i in range(1, 11):
		paths.append("res://content/qaadet_el_sohab/act_it_batch_%02d.json" % i)
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var data = JSON.parse_string(file.get_as_text())
		if not data is Dictionary or not data.get("cards", null) is Array:
			continue
		for card in data["cards"]:
			if card is Dictionary and str(card.get("category", "")) == "act_it":
				var id := str(card.get("id", ""))
				if not id.is_empty() and not seen.has(id) and not str(card.get("text_ar", "")).is_empty():
					seen[id] = true
					result.append(card)
	return result

func _screen(title: String) -> void:
	if timer != null:
		timer.stop()
	for child in get_children():
		if child != timer:
			remove_child(child)
			child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 18)
	scroll.add_child(panel)
	_label(title, 32)
	status = _label("", 19)

func _label(value: String, size: int = 23) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	panel.add_child(label)
	return label

func _button(value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 70
	button.pressed.connect(callback)
	panel.add_child(button)

func _setup_screen() -> void:
	match_started = false
	_screen("مثّل وورّينا")
	_label("كل لاعب يمثّل المشهد في 30 ثانية. الباقي يصوّتوا. الأغلبية المطلوبة من كل المؤهلين، والنجاح = 20 نقطة.", 19)
	names_input = LineEdit.new()
	names_input.text = "لاعب 1، لاعب 2، لاعب 3"
	panel.add_child(names_input)
	rounds_input = OptionButton.new()
	for count in [10, 15, 20]:
		rounds_input.add_item(str(count), count)
	panel.add_child(rounds_input)
	_label("الكروت المتاحة: %d" % cards.size(), 17)
	_button("ابدأ", _start)
	_button("رجوع", _back)

func _start() -> void:
	var names: Array[String] = []
	var unique := {}
	for raw in names_input.text.replace("،", ",").split(","):
		var name := raw.strip_edges()
		if not name.is_empty():
			names.append(name)
			unique[name.to_lower()] = true
	if names.size() < 2 or names.size() > 6 or unique.size() != names.size():
		status.text = "اكتب من 2 إلى 6 أسماء مختلفة."
		return
	var rounds := rounds_input.get_item_id(rounds_input.selected)
	if cards.size() < rounds or not engine.setup(names, cards, rounds) or not engine.lock_category("act_it"):
		status.text = "تعذر تجهيز المباراة أو الكروت غير كافية."
		return
	match_started = true
	_draw_card()

func _draw_card() -> void:
	if engine.round_index >= engine.round_limit:
		_results()
		return
	if engine.current_card.is_empty() and engine.draw_next("act_it").is_empty():
		_results()
		return
	voting = false
	seconds_left = 30
	_screen("مثّل وورّينا — الجولة %d/%d" % [engine.round_index + 1, engine.round_limit])
	_label("دور: %s" % engine.players[engine.active_player_index])
	_label(str(engine.current_card.get("text_ar", "")), 28)
	var countdown := _label("30 ثانية", 25)
	countdown.name = "Countdown"
	_button("ابدأ المؤقت", _begin_timer)
	_button("انتهى التمثيل — التصويت", _vote_screen)
	_button("النتائج الحالية", _results)

func _begin_timer() -> void:
	if not voting and seconds_left > 0:
		timer.start()

func _tick() -> void:
	seconds_left -= 1
	var label := panel.get_node_or_null("Countdown") as Label
	if label != null:
		label.text = "%d ثانية" % maxi(0, seconds_left)
	if seconds_left <= 0:
		timer.stop()
		_vote_screen()

func _vote_screen() -> void:
	if engine.current_card.is_empty():
		return
	voting = true
	_screen("تصويت المجموعة")
	_label("اللاعب: %s" % engine.players[engine.active_player_index])
	_label("صوّتوا واحد واحد. صاحب الدور ممنوع يصوّت.", 19)
	for player in engine.players:
		if player == engine.players[engine.active_player_index] or engine.votes.has(player):
			continue
		_label("تصويت %s — سلّم الجهاز له فقط" % player, 20)
		_button("نجح", _cast.bind(player, true))
		_button("لم ينجح", _cast.bind(player, false))
		break
	_button("إنهاء التصويت بالنتائج المسجلة", func(): _resolve(true))
	_label("النتائج هتظهر بعد انتهاء التصويت؛ علشان التصويت يفضل منفصل.", 16)

func _cast(player: String, passed: bool) -> void:
	if not engine.submit_vote(player, passed):
		status.text = "التصويت غير صالح."
		return
	if engine.votes.size() == engine.players.size() - 1:
		_resolve(false)
	else:
		_vote_screen()

func _resolve(timeout: bool) -> void:
	var result: Dictionary = engine.resolve_round(true, timeout)
	if result.is_empty():
		status.text = "تعذر إنهاء الجولة."
		return
	_screen("نتيجة الجولة")
	_label("النقاط المكتسبة: %s" % str(result.get("awards", {})))
	_button("الجولة التالية", _draw_card)
	_button("ترتيب النقاط", _results)

func _results() -> void:
	_screen("ترتيب النقاط")
	if not match_started:
		_setup_screen()
		return
	var ranking := engine.players.duplicate()
	ranking.sort_custom(func(a, b): return int(engine.scores[a]) > int(engine.scores[b]))
	for i in range(ranking.size()):
		_label("%d. %s — %d نقطة" % [i + 1, ranking[i], int(engine.scores[ranking[i]])])
	if not engine.current_card.is_empty():
		_button("استكمال التصويت", _vote_screen if voting else _draw_card)
	elif engine.round_index < engine.round_limit:
		_button("الجولة التالية", _draw_card)
	_button("مباراة جديدة", _setup_screen)
	_button("رجوع", _back)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/ActItMode.tscn")
