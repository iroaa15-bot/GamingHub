extends Control
## Optional account screen. Existing gameplay remains available without signing in.
const AuthClient = preload("res://scripts/network/gaminghub_auth.gd")
var auth: Node
var email_field: LineEdit
var password_field: LineEdit
var name_field: LineEdit
var status_label: Label
var submit_busy: bool = false
var server_field: LineEdit
const SETTINGS_FILE := "user://gaminghub_identity_endpoint.json"

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        get_tree().change_scene_to_file.call_deferred("res://scenes/Main.tscn")

func _ready() -> void:
    auth = AuthClient.new()
    add_child(auth)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_left = 20
    scroll.offset_right = -20
    scroll.offset_top = 28
    scroll.offset_bottom = -28
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    var center := CenterContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.add_child(center)
    var panel := VBoxContainer.new()
    panel.custom_minimum_size = Vector2(320, 0)
    panel.add_theme_constant_override("separation", 12)
    center.add_child(panel)
    var heading := Label.new()
    heading.text = "Gaming Hub Account / حساب اللاعب"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    panel.add_child(heading)
    server_field = LineEdit.new()
    server_field.placeholder_text = "https://your-identity-api.example"
    panel.add_child(server_field)
    var endpoint_save := Button.new()
    endpoint_save.text = "Save HTTPS account server / حفظ سيرفر الحسابات"
    endpoint_save.pressed.connect(_save_endpoint)
    panel.add_child(endpoint_save)
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
    for action in ["Login / دخول", "Register / تسجيل", "Guest / ضيف", "Upgrade guest / ترقية الضيف", "My profile / حسابي", "Logout / خروج", "Back / رجوع"]:
        var button := Button.new()
        button.text = action
        button.pressed.connect(_on_action.bind(action))
        panel.add_child(button)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(status_label)
    var endpoint := str(ProjectSettings.get_setting("gaminghub/identity_api_url", ""))
    if FileAccess.file_exists(SETTINGS_FILE):
        var stored = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_FILE))
        if stored is Dictionary:
            endpoint = str(stored.get("url", endpoint))
    server_field.text = endpoint
    if not auth.configure(endpoint):
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
    if action.begins_with("Upgrade guest") and auth.access_token.is_empty():
        status_label.text = "Start a guest session first / ابدأ بحساب ضيف أولا"
        return
    if (action.begins_with("Register") or action.begins_with("Upgrade guest")) and (email_field.text.strip_edges().is_empty() or password_field.text.is_empty() or name_field.text.strip_edges().is_empty()):
        status_label.text = "Enter name, email and password / أدخل الاسم والبريد وكلمة المرور"
        return
    submit_busy = true
    var result: Dictionary = {}
    if action.begins_with("Login"):
        result = await auth.login(email_field.text.strip_edges(), password_field.text)
    elif action.begins_with("Register"):
        result = await auth.register_account(email_field.text.strip_edges(), password_field.text, name_field.text.strip_edges())
    elif action.begins_with("Guest"):
        result = await auth.guest()
    elif action.begins_with("Upgrade guest"):
        result = await auth.upgrade_guest(email_field.text.strip_edges(), password_field.text, name_field.text.strip_edges())
    elif action.begins_with("My profile"):
        result = await auth.profile()
    elif action.begins_with("Logout"):
        result = await auth.logout()
    submit_busy = false
    password_field.text = ""
    status_label.text = "Success / تم" if result.get("ok", false) else "Account service unavailable or request rejected. Guest play remains available. / تعذر الطلب؛ اللعب كضيف متاح"
    if result.get("ok", false) and action.begins_with("My profile"):
        var user_data: Dictionary = result.get("data", {}).get("user", {})
        status_label.text = str(user_data.get("display_name", "Player")) + " — Points: " + str(user_data.get("points", 0))


func _save_endpoint() -> void:
    var url := server_field.text.strip_edges().trim_suffix("/")
    if submit_busy: return
    if not auth.configure(url):
        status_label.text = "HTTPS address required / مطلوب رابط HTTPS"
        return
    var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
    if file == null:
        status_label.text = "Could not save server address / تعذر حفظ الرابط"
        return
    file.store_string(JSON.stringify({"url": url}))
    file.close()
    PublishedContent.refresh()
    status_label.text = "Account server saved; checking content availability / تم حفظ الرابط وجارٍ فحص المحتوى"
