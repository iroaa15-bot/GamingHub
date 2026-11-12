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
const ENGLISH := ["Open Heart","Act It","Who Among Us","Show Your Skill","Truth or Fiction","Flip the Table"]
const MenuSkin=preload("res://scripts/visual_skin.gd")
var language: String="ar"
@export_range(-1, 5) var initial_game := -1
var selected_game := -1
var layout: VBoxContainer

func _ready() -> void:
    language=load("res://scripts/player_preferences.gd").language()
    layout_direction=Control.LAYOUT_DIRECTION_RTL if language=="ar" else Control.LAYOUT_DIRECTION_LTR
    selected_game = initial_game
    add_child(load("res://scripts/social_game_backdrop.gd").new())
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
    MenuSkin.decorate_button(button,"secondary")
    button.pressed.connect(action)
    layout.add_child(button)

func _render() -> void:
    _clear()
    if selected_game == -1:
        _label("قعدة الصحاب" if language=="ar" else "Friends gathering")
        for i in range(GAMES.size()):
            var index := i
            _button(GAMES[i]["title"] if language=="ar" else ENGLISH[i], func(): _choose(index))
        _button("رجوع لقائمة الألعاب" if language=="ar" else "Games menu", _home)
    else:
        _label(GAMES[selected_game]["title"] if language=="ar" else ENGLISH[selected_game])
        _button("غرف الأصدقاء" if language=="ar" else "Friend rooms", func(): pass, true)
        layout.get_child(layout.get_child_count()-1).tooltip_text="غرف هذه اللعبة غير متاحة في هذه النسخة" if language=="ar" else "Rooms for this game are unavailable in this build"
        _button("اللعب بدون إنترنت" if language=="ar" else "Play offline", _offline)
        _button("قائمة الألعاب" if language=="ar" else "Games menu", _home)

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

func _home() -> void:
    var account=get_node_or_null("/root/GamingHubAccount")
    if account!=null:account.enter_home_once=true
    get_tree().change_scene_to_file.call_deferred("res://scenes/Main.tscn")
