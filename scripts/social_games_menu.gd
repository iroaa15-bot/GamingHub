extends Control
# Independent game entry. Do not mix Qadet El Sohab and Maana content.
const MAANA_SCENE := "res://scenes/MaanaWalaAlayna.tscn"
var container: VBoxContainer

func _ready() -> void:
    container = VBoxContainer.new()
    container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(container)
    _button("معانا ولا علينا", func(): _open_game(MAANA_SCENE))
    _button("قعدة الصحاب (قريبًا)", func(): pass, true)
    _button("تحدي السينما (قريبًا)", func(): pass, true)
    _button("خمن الصورة (من القائمة الرئيسية)", func(): pass, true)
    _button("خمن الصوت (قريبًا)", func(): pass, true)

func _button(title: String, callback: Callable, disabled: bool = false) -> void:
    var b := Button.new()
    b.text = title
    b.disabled = disabled
    b.custom_minimum_size.y = 76
    container.add_child(b)
    b.pressed.connect(callback)

func _open_game(path: String) -> void:
    get_tree().change_scene_to_file(path)
