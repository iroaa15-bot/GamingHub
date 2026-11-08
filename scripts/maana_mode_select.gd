extends Control
# Three distinct actions. Online is explicitly unavailable until server wiring.
var root: VBoxContainer

func _ready() -> void:
    root = VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)
    _label("معانا ولا علينا")
    _button("العب مع أصحابك • غرف 2–6 (قيد التجهيز)", func(): pass, true)
    _button("العب أوفلاين", func(): get_tree().change_scene_to_file("res://scenes/MaanaWalaAlayna.tscn"))
    _button("رجوع لقائمة الألعاب", func(): get_tree().change_scene_to_file("res://scenes/SocialGamesMenu.tscn"))

func _label(value: String) -> void:
    var l := Label.new()
    l.text = value
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(l)

func _button(value: String, action: Callable, unavailable: bool = false) -> void:
    var b := Button.new()
    b.text = value
    b.disabled = unavailable
    b.custom_minimum_size.y = 72
    root.add_child(b)
    b.pressed.connect(action)
