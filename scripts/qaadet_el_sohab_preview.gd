extends Control
class_name QaadetElSohabPreview

# Isolated local preview; NOT connected to online rooms or production menu.
const Engine = preload("res://scripts/qaadet_el_sohab_engine.gd")
const CONTENT_PATHS = [
	"res://content/qaadet_el_sohab/seed_ar.json",
	"res://content/qaadet_el_sohab/seed_ar_batch02.json"
]
const CATEGORY_NAMES := {
	"": "خلطة المجانين",
	"open_heart": "افتح قلبك",
	"act_it": "مثّل وورّينا",
	"who_among_us": "مين فينا؟",
	"show_skill": "ورّينا شطارتك",
	"truth_or_fiction": "صدق ولا تأليف؟",
	"table_flip": "اقلب الترابيزة"
}
var engine = Engine.new()
@export_enum("open_heart", "act_it", "who_among_us", "show_skill", "truth_or_fiction", "table_flip") var fixed_category := "open_heart"
var selected_category := ""
var heading: Label
var card_text: Label
var status_text: Label
var category_button: OptionButton
var voter_selector: OptionButton
var story_truth_selector: OptionButton
var vote_buttons: HBoxContainer
var action_buttons: HBoxContainer
var cards: Array[Dictionary] = []
var finished_round := false

func _ready() -> void:
	selected_category = fixed_category
	_build_ui()
	cards = _load_cards()
	if cards.is_empty():
		status_text.text = "تعذر تحميل الكروت."
		return
	if not engine.setup(["لاعب 1", "لاعب 2", "لاعب 3"], cards, 20):
		status_text.text = "تعذر بدء المعاينة."
		return
	_draw()

func _load_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for path in CONTENT_PATHS:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary or not parsed.has("cards") or not parsed["cards"] is Array:
			continue
		for item in parsed["cards"]:
			if item is Dictionary and item.has("id") and item.has("category") and item.has("text_ar"):
				var key := str(item["id"])
				if not seen.has(key):
					seen[key] = true
					result.append(item)
	return result

func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 18)
	scroll.add_child(layout)
	heading = Label.new()
	heading.text = CATEGORY_NAMES.get(fixed_category, "لعبة اجتماعية") + " — معاينة أوفلاين"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(heading)
	category_button = OptionButton.new()
	for name in CATEGORY_NAMES:
		category_button.add_item(CATEGORY_NAMES[name])
	category_button.item_selected.connect(_category_changed)
	category_button.visible = false
	layout.add_child(category_button)
	card_text = Label.new()
	card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_text.custom_minimum_size = Vector2(0, 190)
	card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(card_text)
	status_text = Label.new()
	status_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_text)
	voter_selector = OptionButton.new()
	for player in ["لاعب 1", "لاعب 2", "لاعب 3"]:
		voter_selector.add_item(player)
	layout.add_child(voter_selector)
	story_truth_selector = OptionButton.new()
	story_truth_selector.add_item("القصة حقيقية")
	story_truth_selector.add_item("القصة تأليف")
	layout.add_child(story_truth_selector)
	vote_buttons = HBoxContainer.new()
	layout.add_child(vote_buttons)
	action_buttons = HBoxContainer.new()
	layout.add_child(action_buttons)
	_add_action("تخطي / إنهاء الجولة", _finish)
	_add_action("كارت جديد", _draw)
	_add_action("رجوع لاختيار الوضع", _back_to_mode)

func _category_changed(index: int) -> void:
	selected_category = fixed_category
	status_text.text = "الفئة الجديدة هتطبق بعد إنهاء الجولة الحالية."

func _add_action(label_text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.pressed.connect(handler)
	action_buttons.add_child(button)

func _draw() -> void:
	if not engine.current_card.is_empty() and not engine.resolved:
		_show_current_card()
		return
	if engine.round_index >= engine.round_limit:
		card_text.text = "انتهت المعاينة!"
		return
	var card: Dictionary = engine.draw_next(selected_category)
	if card.is_empty():
		status_text.text = "لا توجد كروت متاحة لهذه الفئة، أو الجولة لم تنتهِ."
		return
	_show_current_card()

func _show_current_card() -> void:
	var card: Dictionary = engine.current_card
	if card.is_empty():
		return
	card_text.text = str(card.get("text_ar", ""))
	story_truth_selector.visible = str(card.get("category", "")) == "truth_or_fiction"
	voter_selector.visible = ["act_it", "show_skill", "truth_or_fiction", "who_among_us"].has(str(card.get("category", "")))
	status_text.text = "الجولة %d / %d | دور %s | %s" % [
		engine.round_index + 1, engine.round_limit,
		engine.players[engine.active_player_index],
		CATEGORY_NAMES.get(str(card.get("category", "")), "")
	]
	_refresh_vote_buttons()

func _refresh_vote_buttons() -> void:
	for child in vote_buttons.get_children():
		child.queue_free()
	var category := str(engine.current_card.get("category", ""))
	if category == "act_it" or category == "show_skill" or category == "truth_or_fiction":
		_add_vote("نعم / حقيقة", true)
		_add_vote("لا / تأليف", false)
	elif category == "who_among_us":
		for player in engine.players:
			_add_vote(player, player)

func _add_vote(label_text: String, value: Variant) -> void:
	var button := Button.new()
	button.text = label_text
	button.pressed.connect(func() -> void:
		var voter := str(voter_selector.get_item_text(voter_selector.selected))
		if engine.submit_vote(voter, value):
			status_text.text = "تم تسجيل تصويت %s. اختر اللاعب التالي." % voter
		else:
			status_text.text = "التصويت مرفوض: راجع الدور أو التصويت السابق أو اختيار النفس."
	)
	vote_buttons.add_child(button)

func _back_to_mode() -> void:
	var scene_by_category := {
		"open_heart": "OpenHeartMode",
		"act_it": "ActItMode",
		"who_among_us": "WhoAmongUsMode",
		"show_skill": "ShowSkillMode",
		"truth_or_fiction": "TruthOrFictionMode",
		"table_flip": "TableFlipMode"
	}
	var scene_name := str(scene_by_category.get(fixed_category, ""))
	if not scene_name.is_empty():
		get_tree().change_scene_to_file("res://scenes/" + scene_name + ".tscn")

func _finish() -> void:
	if engine.current_card.is_empty():
		return
	var truth := story_truth_selector.selected == 0
	var result: Dictionary = engine.resolve_round(truth)
	status_text.text = "النقاط: %s" % str(result.get("scores", {}))
	card_text.text = "انتهت الجولة. اضغط كارت جديد."
	for child in vote_buttons.get_children():
		child.queue_free()
