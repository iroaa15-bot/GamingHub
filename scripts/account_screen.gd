extends Control
## Optional account screen. Existing gameplay remains available without signing in.
const AuthClient = preload("res://scripts/network/gaminghub_auth.gd")
var auth: Node
var email_field: LineEdit
var password_field: LineEdit
var name_field: LineEdit
var status_label: Label
var submit_busy: bool = false

func _ready() -> void:
    auth = AuthClient.new()
    add_child(auth)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel := VBoxContainer.new()
    panel.custom_minimum_size = Vector2(320, 0)
    panel.add_theme_constant_override("separation", 12)
    center.add_child(panel)
    var heading := Label.new()
    heading.text = "Gaming Hub Account / حساب اللاعب"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    panel.add_child(heading)
    name_field = LineEdit.new()
    name_field.placeholder_text = "Player name / اسم اللاعب"
    panel.add_child(name_field)
    email_field = LineEdit.new()
    email_field.placeholder_text = "Email / البريد الإلكتروني"
    panel.add_child(email_field)
    password_field = LineEdit.new()
    password_field.placeholder_text = "Password / كلمة المرور"
    password_field.secret = true
    panel.add_child(password_field)
    for action in ["Login / دخول", "Register / تسجيل", "Guest / ضيف", "My profile / حسابي", "Logout / خروج", "Back / رجوع"]:
        var button := Button.new()
        button.text = action
        button.pressed.connect(_on_action.bind(action))
        panel.add_child(button)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(status_label)
    if not auth.configure(ProjectSettings.get_setting("gaminghub/identity_api_url", "")):
        status_label.text = "Online accounts unavailable. Guest gameplay remains available. / الحسابات غير مفعلة حاليا"

func _on_action(action: String) -> void:
    if action.begins_with("Back"):
        get_tree().change_scene_to_file("res://scenes/Main.tscn")
        return
    if submit_busy:
        return
    if auth.api_base.is_empty():
        status_label.text = "Online account server not configured / سيرفر الحسابات غير مهيأ"
        return
    submit_busy = true
    var result: Dictionary = {}
    if action.begins_with("Login"):
        result = await auth.login(email_field.text.strip_edges(), password_field.text)
    elif action.begins_with("Register"):
        result = await auth.register_account(email_field.text.strip_edges(), password_field.text, name_field.text.strip_edges())
    elif action.begins_with("Guest"):
        result = await auth.guest()
    elif action.begins_with("My profile"):
        result = await auth.profile()
    elif action.begins_with("Logout"):
        result = await auth.logout()
    submit_busy = false
    status_label.text = "Success / تم" if result.get("ok", false) else "Request failed / تعذر تنفيذ الطلب"
    if result.get("ok", false) and action.begins_with("My profile"):
        var user_data: Dictionary = result.get("data", {}).get("user", {})
        status_label.text = str(user_data.get("display_name", "Player")) + " — Points: " + str(user_data.get("points", 0))
