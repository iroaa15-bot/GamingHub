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

func _ready() -> void:
    var f := FileAccess.open(DATA_PATH, FileAccess.READ)
    if f != null:
        var parsed: Variant = JSON.parse_string(f.get_as_text())
        if parsed is Dictionary and parsed.get("rounds", []) is Array:
            cards = parsed["rounds"]
    panel = VBoxContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(panel)
    _new_card()

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
    if deck.is_empty():
        deck = cards.duplicate(true)
        deck.shuffle()
    card = deck.pop_back() if not deck.is_empty() else {}
    step = 0
    _draw()

func _draw() -> void:
    _clear()
    _label("معانا ولا علينا")
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
        _label("نتيجة الجولة: " + str(reveal.get("status", "")))
        _label("الأقلية: " + str(reveal.get("minority", [])))
        _label("العقوبات: " + str(penalties))
        _button("الجولة التالية", _new_card)

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
            # Same-device prototype: pass phone to minority for ordered reactions.
            # Real-time reaction race requires online server timestamps.
            pass
    step += 1
    _draw()
