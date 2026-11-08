extends Control
## Offline pass-and-play truth or fiction. A single shared screen cannot guarantee privacy.
const Engine = preload("res://scripts/qaadet_el_sohab_engine.gd")
const SEEDS = ["res://content/qaadet_el_sohab/seed_ar.json", "res://content/qaadet_el_sohab/seed_ar_batch02.json"]
var engine = Engine.new()
var cards: Array[Dictionary] = []
var panel: VBoxContainer
var status: Label
var names_input: LineEdit
var rounds_input: OptionButton
var timer: Timer
var seconds_left := 60
var phase := "setup"
var match_started := false
var revealed_truth := false

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
		paths.append("res://content/qaadet_el_sohab/truth_or_fiction_batch_%02d.json" % i)
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
			if card is Dictionary and str(card.get("category", "")) == "truth_or_fiction":
				var id := str(card.get("id", ""))
				if not id.is_empty() and not seen.has(id) and not str(card.get("text_ar", "")).is_empty():
					seen[id] = true
					result.append(card)
	return result

func _screen(title: String) -> void:
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
	status = _label("", 18)

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
	phase = "setup"
	match_started = false
	_screen("صدق ولا تأليف؟")
	_label("صاحب الدور يختار حقيقة أو تأليف سرًا قبل الحكاية. كل تخمين صحيح = 10 نقاط. الراوي يكسب 10 لو خدع أغلبية كل المصوّتين المؤهلين.", 19)
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
	var seen := {}
	for raw in names_input.text.replace("،", ",").split(","):
		var name := raw.strip_edges()
		if not name.is_empty():
			names.append(name)
			seen[name.to_lower()] = true
	if names.size() < 2 or names.size() > 6 or seen.size() != names.size():
		status.text = "اكتب من 2 إلى 6 أسماء مختلفة."
		return
	var rounds := rounds_input.get_item_id(rounds_input.selected)
	if cards.size() < rounds or not engine.setup(names, cards, rounds) or not engine.lock_category("truth_or_fiction"):
		status.text = "تعذر تجهيز المباراة."
		return
	match_started = true
	_next()

func _next() -> void:
	if engine.round_index >= engine.round_limit:
		_results()
		return
	if engine.current_card.is_empty() and engine.draw_next("truth_or_fiction").is_empty():
		_results()
		return
	phase = "commit"
	_screen("الراوي فقط — الجولة %d/%d" % [engine.round_index + 1, engine.round_limit])
	_label("الراوي: %s" % engine.players[engine.active_player_index])
	_label(str(engine.current_card.get("text_ar", "")), 26)
	_label("خلي الشاشة معاك وحدك واختار نوع قصتك قبل ما تحكي.", 18)
	_button("هحكي حقيقة", _commit.bind(true))
	_button("هألف قصة", _commit.bind(false))
	_button("النتائج الحالية", _results)

func _commit(is_true: bool) -> void:
	var actor := engine.players[engine.active_player_index]
	if not engine.commit_story(actor, is_true):
		status.text = "تعذر تثبيت اختيار الراوي."
		return
	_story()

func _story() -> void:
	phase = "story"
	seconds_left = 60
	_screen("وقت الحكاية")
	_label(str(engine.current_card.get("text_ar", "")), 26)
	_label("الراوي: %s" % engine.players[engine.active_player_index])
	var countdown := _label("60 ثانية", 25)
	countdown.name = "Countdown"
	_button("ابدأ المؤقت", func(): timer.start())
	_button("انتهت الحكاية — ابدأ التخمين", _vote)
	_button("النتائج الحالية", _results)

func _tick() -> void:
	seconds_left -= 1
	var countdown := panel.get_node_or_null("Countdown") as Label
	if countdown != null:
		countdown.text = "%d ثانية" % maxi(0, seconds_left)
	if seconds_left <= 0:
		timer.stop()
		_vote()

func _vote() -> void:
	phase = "vote"
	_screen("تخمين الحقيقة")
	_label("هل الحكاية حقيقة ولا تأليف؟ مرّر الموبايل لمصوّت واحد في كل مرة.", 20)
	for voter in engine.players:
		if voter == engine.players[engine.active_player_index] or engine.votes.has(voter):
			continue
		_label("المصوّت: %s" % voter)
		_button("حقيقة", _cast.bind(voter, true))
		_button("تأليف", _cast.bind(voter, false))
		break
	_button("إنهاء التخمين بالأصوات الحالية", _resolve.bind(true))
	_button("النتائج الحالية", _results)

func _cast(voter: String, guess: bool) -> void:
	if not engine.submit_vote(voter, guess):
		status.text = "التصويت مرفوض."
		return
	if engine.votes.size() == engine.players.size() - 1:
		_resolve(false)
	else:
		_vote()

func _resolve(timeout: bool) -> void:
	revealed_truth = engine.committed_story_truth
	var result: Dictionary = engine.resolve_round(true, timeout)
	if result.is_empty():
		status.text = "تعذر إنهاء الجولة."
		return
	phase = "resolved"
	_screen("انتهت الجولة")
	_label("الحكاية كانت: %s" % ("حقيقة" if revealed_truth else "تأليف"))
	_label("النقاط المكتسبة: %s" % str(result.get("awards", {})))
	_button("الجولة التالية", _next)
	_button("ترتيب النقاط", _results)

func _results() -> void:
	if not match_started:
		_setup_screen()
		return
	var previous_phase := phase
	_screen("ترتيب النقاط")
	phase = previous_phase
	var ranking := engine.players.duplicate()
	ranking.sort_custom(func(a, b): return int(engine.scores[a]) > int(engine.scores[b]))
	for i in range(ranking.size()):
		_label("%d. %s — %d نقطة" % [i + 1, ranking[i], int(engine.scores[ranking[i])]])
	if not engine.current_card.is_empty():
		if phase == "commit":
			_button("استكمال اختيار الراوي", _next)
		elif phase == "story":
			_button("استكمال الحكاية", _story)
		else:
			_button("استكمال التخمين", _vote)
	elif engine.round_index < engine.round_limit:
		_button("الجولة التالية", _next)
	_button("مباراة جديدة", _setup_screen)
	_button("رجوع", _back)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/TruthOrFictionMode.tscn")
