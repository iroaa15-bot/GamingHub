extends Control
## Standalone entry points for six social games. Online disabled until verified.
const GAMES := [
    {"title": "افتح قلبك", "scene": "res://scenes/OpenHeart.tscn"},
    {"title": "مثّل وورّينا", "scene": "res://scenes/ActIt.tscn"},
    {"title": "مين فينا؟", "scene": "res://scenes/WhoAmongUs.tscn"},
    {"title": "ورّينا شطارتك", "scene": "res://scenes/ShowSkill.tscn"},
    {"title": "صدق ولا تأليف؟", "scene": "res://scenes/TruthOrFiction.tscn"},
    {"title": "اقلب الترابيزة", "scene": "res://scenes/TableFlip.tscn"}
]
@export_range(-1, 5) var initial_game := -1
var selected_game := -1
var layout: VBoxContainer

func _ready() -> void:
    selected_game = initial_game
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(scroll)
    layout = VBoxContainer.new()
    layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(layout)
    _render()

func _clear() -> void:
    for child in layout.get_children():
        layout.remove_child(child)
        child.queue_free()

func _label(value: String) -> void:
    var label := Label.new()
    label.text = value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    layout.add_child(label)

func _button(value: String, action: Callable, disabled: bool = false) -> void:
    var button := Button.new()
    button.text = value
    button.disabled = disabled
    button.custom_minimum_size.y = 76
    button.pressed.connect(action)
    layout.add_child(button)

func _render() -> void:
    _clear()
    if selected_game == -1:
        _label("الألعاب الاجتماعية المستقلة")
        for i in range(GAMES.size()):
            var index := i
            _button(GAMES[i]["title"], func(): _choose(index))
        _button("رجوع لقائمة الألعاب", func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
    else:
        _label(GAMES[selected_game]["title"])
        _button("العب مع أصحابك (قيد التجهيز)", func(): pass, true)
        _button("العب أوفلاين", _offline)
        _button("رجوع لقائمة الألعاب", _back)

func _choose(index: int) -> void:
    selected_game = index
    _render()

func _offline() -> void:
    get_tree().change_scene_to_file(GAMES[selected_game]["scene"])

func _back() -> void:
    if initial_game >= 0:
        get_tree().change_scene_to_file("res://scenes/Main.tscn")
        return
    selected_game = -1
    _render()
