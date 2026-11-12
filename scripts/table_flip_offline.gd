extends Control
## Standalone local Table Flip rules. Legacy cross-game cards are mapped to local effects.
const SEEDS = ["res://content/qaadet_el_sohab/seed_ar.json", "res://content/qaadet_el_sohab/seed_ar_batch02.json"]
const LEGACY = {
"001":"swap","002":"bonus","003":"shield","004":"choice","005":"double",
"006":"choice","007":"choice","008":"double","009":"reverse","010":"shield",
"011":"skip","012":"reverse","013":"choice","014":"reverse","015":"skip",
"016":"swap","017":"choice","018":"choice","019":"double","020":"bonus",
"021":"shield","022":"reverse"}
var cards: Array[Dictionary] = []
var used := {}
var players: Array[String] = []
var scores := {}
var shields := {}
var doubles := {}
var skips := {}
var order: Array[String] = []
var current_index := 0
var direction := 1
var round := 0
var max_rounds := 20
var current: Dictionary = {}
var panel: VBoxContainer
var status: Label
var names_input: LineEdit
var rounds_input: OptionButton
var target_input: OptionButton
var rng := RandomNumberGenerator.new()
var pending_choice := false
var offered: Array[Dictionary] = []

func _ready() -> void:
	cards = _load_cards()
	rng.randomize()
	_setup()

func _load_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids := {}
	var paths := SEEDS.duplicate()
	for i in range(1, 11):
		paths.append("res://content/qaadet_el_sohab/table_flip_batch_%02d.json" % i)
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary or not parsed.get("cards", null) is Array:
			continue
		for card in parsed["cards"]:
			if card is Dictionary and str(card.get("category", "")) == "table_flip":
				var id := str(card.get("id", ""))
				if not id.is_empty() and not ids.has(id):
					ids[id] = true
					result.append(card)
	return result

func _screen(title: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 16)
	scroll.add_child(panel)
	_label(title, 31)
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
	button.custom_minimum_size.y = 72
	button.pressed.connect(callback)
	panel.add_child(button)

func _setup() -> void:
	_screen("اقلب الترابيزة")
	_label("كروت قوى تغيّر الأدوار والنقاط. كل تأثير ينفذ مرة واحدة. الدرع يحمي من الخصم، والمضاعف لأول مكافأة.", 19)
	names_input = LineEdit.new()
	names_input.text = "لاعب 1، لاعب 2، لاعب 3"
	panel.add_child(names_input)
	rounds_input = OptionButton.new()
	for n in [10, 15, 20]:
		rounds_input.add_item(str(n), n)
	panel.add_child(rounds_input)
	_label("الكروت: %d" % cards.size(), 17)
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
	if names.size() < 2 or names.size() > 6 or names.size() != unique.size() or cards.size() < 20:
		status.text = "لازم من 2 إلى 6 أسماء مختلفة وكروت كفاية."
		return
	players = names
	order = names.duplicate()
	scores.clear()
	shields.clear()
	doubles.clear()
	skips.clear()
	used.clear()
	for p in names:
		scores[p] = 0
		shields[p] = 0
		doubles[p] = 0
		skips[p] = 0
	current_index = 0
	direction = 1
	round = 0
	max_rounds = rounds_input.get_item_id(rounds_input.selected)
	pending_choice = false
	offered.clear()
	current.clear()
	_draw_card()

func _available() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in cards:
		if not used.has(card["id"]):
			result.append(card)
	return result

func _draw_card() -> void:
	if round >= max_rounds:
		_results()
		return
	var available := _available()
	if available.is_empty():
		_results()
		return
	if pending_choice and available.size() >= 2:
		if offered.is_empty():
			var first := rng.randi_range(0, available.size()-1)
			offered.append(available[first])
			available.remove_at(first)
			offered.append(available[rng.randi_range(0, available.size()-1)])
		_screen("اختار كارت واحد")
		for card in offered:
			_button(str(card.get("text_ar", "")), _choose.bind(str(card["id"])))
		return
	pending_choice = false
	offered.clear()
	_choose(str(available[rng.randi_range(0, available.size()-1)]["id"]))

func _choose(card_id: String) -> void:
	var found := false
	for card in _available():
		if str(card["id"]) == card_id:
			current = card.duplicate(true)
			found = true
			break
	var offered_valid := offered.is_empty()
	for offer in offered:
		if str(offer.get("id", "")) == card_id:
			offered_valid = true
	if not found or not offered_valid:
		return
	used[card_id] = true
	pending_choice = false
	offered.clear()
	_show()

func _type() -> String:
	var kind := str(current.get("power_type", ""))
	if not kind.is_empty():
		return kind
	var id := str(current.get("id", ""))
	return str(LEGACY.get(id.trim_prefix("qs_power_"), "self_bonus"))

func _show() -> void:
	_screen("اقلب الترابيزة — الجولة %d/%d" % [round+1,max_rounds])
	_label("الدور على: %s" % order[current_index])
	_label(str(current.get("text_ar", "")), 26)
	_label("التأثير الفعلي: " + _effect_explanation(_type()), 17)
	var kind := _type()
	if ["bonus","steal","skip"].has(kind):
		target_input = OptionButton.new()
		for p in order:
			if p != order[current_index]:
				target_input.add_item(p)
		panel.add_child(target_input)
	_button("نفّذ تأثير الكارت", _apply)
	_button("ترتيب النقاط", _results)

func _effect_explanation(kind: String) -> String:
	match kind:
		"reverse": return "اعكس اتجاه الأدوار"
		"swap": return "بدّل ترتيب اللاعبين التاليين من غير تكرار دورك"
		"bonus": return "امنح لاعبًا 5 نقاط"
		"steal": return "انقل حتى 5 نقاط من لاعب إليك"
		"shield": return "احصل على درع ضد خصم النقاط"
		"skip": return "اجعل لاعبًا يتخطى دوره القادم"
		"double": return "ضاعف أول مكافأة نقاط قادمة لك"
		"gift": return "امنح اللاعب التالي 5 نقاط"
		"choice": return "اختر بين كارتين في دورك القادم"
	return "احصل على 5 نقاط"

func _grant(player: String, amount: int) -> void:
	if int(doubles[player]) > 0:
		amount *= 2
		doubles[player] -= 1
	scores[player] += amount

func _apply() -> void:
	if current.is_empty():
		return
	var actor := order[current_index]
	var kind := _type()
	var target := ""
	if ["bonus","steal","skip"].has(kind):
		target = target_input.get_item_text(target_input.selected)
	match kind:
		"reverse":
			direction *= -1
		"swap":
			# Swap the two upcoming seats; the acting player must not get an extra turn.
			if order.size() >= 3:
				var first := posmod(current_index + direction, order.size())
				var second := posmod(current_index + 2 * direction, order.size())
				var tmp := order[first]
				order[first] = order[second]
				order[second] = tmp
		"bonus":
			_grant(target, 5)
		"steal":
			if int(shields[target]) > 0:
				shields[target] -= 1
			else:
				var amount := mini(5, int(scores[target]))
				scores[target] -= amount
				_grant(actor, amount)
		"shield":
			shields[actor] += 1
		"skip":
			skips[target] += 1
		"double":
			doubles[actor] += 1
		"gift":
			_grant(order[posmod(current_index+direction,order.size())], 5)
		"self_bonus":
			_grant(actor, 5)
		"choice":
			pending_choice = true
		_:
			status.text = "تأثير غير معروف؛ لم تُحتسب الجولة."
			return
	round += 1
	current.clear()
	current_index = posmod(current_index + direction, order.size())
	var skipped := 0
	while skipped < order.size() and int(skips[order[current_index]]) > 0:
		skips[order[current_index]] -= 1
		current_index = posmod(current_index + direction, order.size())
		skipped += 1
	_screen("تم تنفيذ القوة")
	_label("النقاط: %s" % str(scores))
	_button("الكارت التالي", _draw_card)
	_button("ترتيب النقاط", _results)

func _results() -> void:
	_screen("النتائج — اقلب الترابيزة")
	var ranking := order.duplicate()
	ranking.sort_custom(func(a,b): return int(scores[a]) > int(scores[b]))
	for i in range(ranking.size()):
		_label("%d. %s — %d نقطة" % [i+1,ranking[i],int(scores[ranking[i]])])
	if not current.is_empty():
		_button("استكمال الكارت", _show)
	elif round < max_rounds:
		_button("استكمال المباراة", _draw_card)
	_button("مباراة جديدة", _setup)
	_button("رجوع", _back)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/TableFlipMode.tscn")
