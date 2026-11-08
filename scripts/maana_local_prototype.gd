extends Control
## Local pass-and-play prototype for Maana Wala Alayna.
## Online rooms require a separate server integration.
const Rules = preload("res://scripts/maana_rules.gd")
const DATA_PATH = "res://data/maana_wala_alayna.json"
var cards: Array = []
var deck: Array = []
var players: Array = ["لاعب 1", "لاعب 2", "لاعب 3"]
var penalties: Dictionary = {}
var votes: Dictionary = {}
var card: Dictionary = {}
var step := 0
var reveal: Dictionary = {}
var reaction_order: Array = []
var panel: VBoxContainer
var awaiting_penalty := false
var penalty_candidates: Array = []
var selected_penalty: String = ""
var completed_rounds := 0
const MATCH_ROUNDS := 15
var setup_count := 3
var setup_done := false

func _ready() -> void:
    var f := FileAccess.open(DATA_PATH, FileAccess.READ)
    if f != null:
        var parsed: Variant = JSON.parse_string(f.get_as_text())
        if parsed is Dictionary and parsed.get("rounds", []) is Array:
            cards = parsed["rounds"]
    panel = VBoxContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(panel)
    _draw()

func _button(caption: String, action: Callable) -> void:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size.y = 66
    b.pressed.connect(action)
    panel.add_child(b)

func _label(caption: String) -> void:
    var l := Label.new()
    l.text = caption
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(l)

func _clear() -> void:
    for child in panel.get_children():
        child.queue_free()

func _new_card() -> void:
    votes.clear()
    reaction_order.clear()
    awaiting_penalty = false
    penalty_candidates.clear()
    selected_penalty = ""
    if deck.is_empty():
        deck = cards.duplicate(true)
        deck.shuffle()
    card = deck.pop_back() if not deck.is_empty() else {}
    step = 0
    _draw()

func _draw() -> void:
    _clear()
    _label("معانا ولا علينا")
    if setup_done and completed_rounds >= MATCH_ROUNDS:
        _show_final_standings()
        return
    if not setup_done:
        _label("اختار عدد اللاعبين للأوفلاين")
        for count in range(2, 7):
            var chosen := count
            _button(str(count) + " لاعبين", func(): _start_players(chosen))
        _button("رجوع", func(): get_tree().change_scene_to_file("res://scenes/MaanaModeSelect.tscn"))
        return
    if card.is_empty():
        _label("ملف الـ500 كارت غير موجود في data/maana_wala_alayna.json")
        return
    if step < players.size():
        var player: String = players[step]
        _label("الدور على: " + player + " — خلّي باقي اللاعبين يبعدوا عن الشاشة")
        _label("1 — " + str(card.get("option_1", "")))
        _label("2 — " + str(card.get("option_2", "")))
        _button("اختيار 1", func(): _vote(player, 1))
        _button("اختيار 2", func(): _vote(player, 2))
    elif step == players.size():
        _label("كل اللاعبين صوتوا. اكشف النتيجة.")
        _button("اكشف", _show_result)
    else:
        if awaiting_penalty:
            _label("الأقلية: " + str(penalty_candidates))
            _label("بعد تحدي الإيد فوق، مين كان آخر واحد؟")
            for id in penalty_candidates:
                var chosen: String = str(id)
                _button(chosen, func(): _assign_penalty(chosen))
            return
        _label("نتيجة الجولة: " + str(reveal.get("status", "")))
        _label("الأقلية: " + str(reveal.get("minority", [])))
        _label("العقوبات: " + str(penalties))
        _button("الجولة التالية", _finish_round)

func _start_players(count: int) -> void:
    players.clear()
    for i in range(count):
        players.append("لاعب " + str(i + 1))
    penalties.clear()
    completed_rounds = 0
    setup_done = true
    _new_card()

func _vote(player: String, choice: int) -> void:
    if votes.has(player):
        return
    votes[player] = choice
    step += 1
    _draw()

func _show_result() -> void:
    reveal = Rules.resolve(votes, players)
    if reveal.get("status") == "minority":
        var minority: Array = reveal["minority"]
        if minority.size() == 1:
            penalties = Rules.apply_penalty(penalties, minority[0])
        else:
            # Offline physical reaction: players decide who was last.
            # No automated timing or server race is claimed.
            penalty_candidates = minority.duplicate()
            awaiting_penalty = true
    step += 1
    _draw()

func _assign_penalty(player_id: String) -> void:
    if not awaiting_penalty or player_id not in penalty_candidates:
        return
    penalties = Rules.apply_penalty(penalties, player_id)
    awaiting_penalty = false
    selected_penalty = player_id
    _draw()

func _finish_round() -> void:
    if awaiting_penalty:
        return
    completed_rounds += 1
    if completed_rounds >= MATCH_ROUNDS:
        _draw()
    else:
        _new_card()

func _show_final_standings() -> void:
    _label("انتهت المباراة بعد %d جولة" % MATCH_ROUNDS)
    var lowest := 999999
    for player in players:
        lowest = mini(lowest, int(penalties.get(player, 0)))
    var winners: Array = []
    for player in players:
        var count := int(penalties.get(player, 0))
        _label("%s — %d كروت عقوبة" % [player, count])
        if count == lowest:
            winners.append(player)
    _label("الفائز: " + ", ".join(winners) if winners.size() == 1 else "تعادل في المركز الأول: " + ", ".join(winners))
    _button("العب من جديد", func(): setup_done = false; _draw())
    _button("رجوع لقائمة الألعاب", func(): get_tree().change_scene_to_file("res://scenes/SocialGamesMenu.tscn"))
