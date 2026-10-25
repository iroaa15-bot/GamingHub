extends Control
## Photo Duel screen embedded in the original Gaming Hub application.
## Does not touch existing game rooms, audio, AdMob, or production services.
const HOME := "res://scenes/Main.tscn"
const FACT_LABELS := {
 "living": "هل هو كائن حي؟", "animal": "هل هو حيوان؟",
 "celebrity": "هل هو شخص مشهور؟", "edible": "هل يمكن أكله؟",
 "household": "هل يُستخدم في المنزل؟", "natural": "هل يوجد في الطبيعة؟",
 "place": "هل هو مكان؟", "large": "هل حجمه كبير؟"
}
var socket := WebSocketPeer.new()
var connected := false
var session_code := ""
var resume_token := ""
var state: Dictionary = {}
var status_label: Label
var panel: VBoxContainer
var address_field: LineEdit
var code_field: LineEdit
var text_field: LineEdit
var guess_field: LineEdit
var requested_action: Dictionary = {}
var server_url := ""
var language := "ar"
var ui_generation := 0
var last_feedback := ""
const VisualSkin = preload("res://scripts/visual_skin.gd")
var previous_state := WebSocketPeer.STATE_CLOSED
var mic_probe: Node
var mic_level_label: Label
var mic_probe_active := false
var voice_receiver: Node
var voice_question_active := false

func _ready() -> void:
 var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://progress_v10_all.json")) if FileAccess.file_exists("user://progress_v10_all.json") else null
 if saved is Dictionary:
  language = str(saved.get("language", "ar"))
 var config: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/network_config.json"))
 if config is Dictionary:
  server_url = str(config.get("server_url", ""))
 _draw_lobby()
 mic_probe = load("res://scripts/photo_duel_mic_probe_staging.gd").new()
 add_child(mic_probe)
 mic_probe.microphone_level.connect(_on_mic_level)
 mic_probe.audio_frame.connect(_on_voice_frame)
 voice_receiver = load("res://scripts/photo_duel_voice_receiver_staging.gd").new()
 add_child(voice_receiver)
 set_process(true)

func _process(_delta: float) -> void:
 socket.poll()
 var current := socket.get_ready_state()
 if current == WebSocketPeer.STATE_OPEN:
  if not connected:
   connected = true
   _status("متصل بالسيرفر التجريبي")
   _send(requested_action)
  while socket.get_available_packet_count() > 0:
   var payload: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
   if payload is Dictionary:
    _received(payload)
 elif current == WebSocketPeer.STATE_CLOSED and previous_state != WebSocketPeer.STATE_CLOSED:
  connected = false
  _draw_lobby()
  _status("انقطع الاتصال؛ استخدم استعادة الجلسة")
 previous_state = current

func _send(payload: Dictionary) -> void:
 if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
  _status("لا يوجد اتصال بالسيرفر")
  return
 socket.send_text(JSON.stringify(payload))

func _connect_and_send(payload: Dictionary) -> void:
 if connected:
  _send(payload)
  return
 if socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
  _status("الاتصال جارٍ")
  return
 requested_action = payload
 server_url = address_field.text.strip_edges() if is_instance_valid(address_field) else server_url
 if not server_url.begins_with("ws://") and not server_url.begins_with("wss://"):
  _status("عنوان السيرفر يجب أن يبدأ بـ ws:// أو wss://")
  return
 socket = WebSocketPeer.new()
 var err := socket.connect_to_url(server_url)
 if err != OK:
  _status(("Connection failed: " if language == "en" else "تعذر بدء الاتصال: ") + str(err))
 else:
  _status("جارٍ الاتصال...")
 previous_state = WebSocketPeer.STATE_CONNECTING

func _received(message: Dictionary) -> void:
 var kind := str(message.get("type", ""))
 match kind:
  "photo_created", "photo_joined", "photo_resumed":
   session_code = str(message.get("code", session_code))
   resume_token = str(message.get("token", ""))
   _status(("Room " if language == "en" else "غرفة ") + session_code + (" • connected" if language == "en" else " • الجلسة متصلة"))
   _draw_match()
  "photo_waiting":
   _status(("Waiting for opponent • room code: " if language == "en" else "في انتظار اللاعب الثاني • كود الغرفة: ") + session_code)
  "photo_state":
   state = message
   _draw_match()
   _sync_voice()
  "photo_voice":
   if is_instance_valid(voice_receiver):
    voice_receiver.receive_pcm(str(message.get("pcm", "")))
  "photo_error":
   _status(("Error: " if language == "en" else "خطأ: ") + str(message.get("message", "غير معروف")))
  "photo_question":
   last_feedback = str(message.get("text", ""))
   if str(message.get("mode", "")) == "tap":
    last_feedback = _localized(str(FACT_LABELS.get(str(message.get("question_id", "")), ""))) + " " + _yes_no(bool(message.get("answer", false)))
   elif str(message.get("mode", "")) == "voice":
    last_feedback = "Voice question" if language == "en" else "سؤال صوتي"
   _draw_match()
  "photo_reply":
   last_feedback = ("Opponent reply: " if language == "en" else "إجابة المنافس: ") + _yes_no(bool(message.get("answer", false)))
   _draw_match()
  "photo_turn", "photo_guess_pending", "photo_guess_result", "photo_finished":
   _status(("Event: " if language == "en" else "حدث: ") + kind)
  _:
   pass

func _clear() -> void:
 ui_generation += 1
 for child in get_children():
  if child == mic_probe or child == voice_receiver:
   continue
  remove_child(child)
  child.queue_free()
 var background := VisualSkin.new()
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(background)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.scroll_deadzone = 22
 add_child(scroll)
 var margin := MarginContainer.new()
 margin.add_theme_constant_override("margin_left", 16)
 margin.add_theme_constant_override("margin_right", 16)
 margin.add_theme_constant_override("margin_top", 20)
 margin.add_theme_constant_override("margin_bottom", 20)
 scroll.add_child(margin)
 panel = VBoxContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 panel.add_theme_constant_override("separation", 12)
 margin.add_child(panel)
 _label("🖼️ خمن صورتك — PHOTO DUEL", 27)
 _label("يتطلب خادم الغرف تفعيل تحدي الصور", 15)
 status_label = _label("جاهز", 16)

func _label(value: String, size: int = 19) -> Label:
 var label_node := Label.new()
 label_node.text = _localized(value)
 label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label_node.add_theme_font_size_override("font_size", size)
 panel.add_child(label_node)
 return label_node

func _field(placeholder: String, value: String = "") -> LineEdit:
 var field := LineEdit.new()
 field.placeholder_text = _localized(placeholder)
 field.text = value
 field.custom_minimum_size.y = 55
 panel.add_child(field)
 return field

func _button(value: String, callback: Callable) -> void:
 var b := Button.new()
 b.text = _localized(value)
 b.custom_minimum_size.y = 54
 VisualSkin.decorate_button(b, "gold")
 b.pressed.connect(_invoke_action.bind(weakref(b), ui_generation, callback), CONNECT_DEFERRED)
 panel.add_child(b)

func _status(value: String) -> void:
 if is_instance_valid(status_label):
  status_label.text = _localized(value)
 print("[PHOTO_STAGING] ", value)

func _draw_lobby() -> void:
 _stop_mic_probe()
 _clear()
 address_field = _field("عنوان خادم الغرف", server_url)
 code_field = _field("كود الغرفة للانضمام", session_code)
 _button("إنشاء غرفة", func(): _connect_and_send({"type":"photo_create","target":10,"timer":30,"reward":1}))
 _button("الانضمام للغرفة", func(): _connect_and_send({"type":"photo_join","code":code_field.text.strip_edges().to_upper()}))
 _button("استعادة الجلسة", func(): _connect_and_send({"type":"photo_resume","code":code_field.text.strip_edges().to_upper(),"token":resume_token}))
 _button("العودة للقائمة الرئيسية", _home)

func _draw_match() -> void:
 _clear()
 _label(("Room code: " if language == "en" else "كود الغرفة: ") + session_code)
 if not last_feedback.is_empty():
  _label(last_feedback)
 if state.is_empty():
  _label("في انتظار دخول اللاعب الثاني...")
  _button("تحديث الحالة", func(): _send({"type":"photo_sync"}))
  _button("العودة", _draw_lobby)
  return
 var me := int(state.get("player", -1))
 var current := int(state.get("current", -1))
 var scores: Array = state.get("scores", [0, 0])
 _label(("Player %d | round %d | score %s" if language == "en" else "اللاعب %d | الجولة %d | النقاط %s") % [me + 1, int(state.get("round", 1)), str(scores)])
 if bool(state.get("closed", false)):
  _label("تم إغلاق الغرفة")
  _button("العودة", _draw_lobby)
  return
 if bool(state.get("finished", false)):
  _label("انتهت المباراة")
  _button("العودة", _draw_lobby)
  return
 if bool(state.get("pending_question", false)) and str(state.get("question_mode", "")) == "text":
  _label(str(state.get("question_text", "")))
 if bool(state.get("awaiting_confirmation", false)):
  _label(str(state.get("guess_text", "")))
 var visible: Dictionary = state.get("visible_opponent_image", {})
 var image_path := str(visible.get("image", ""))
 _label("صورة المنافس (لا تظهر له على جهازه):", 16)
 if image_path.begins_with("res://assets/") and ResourceLoader.exists(image_path):
  var texture := load(image_path) as Texture2D
  if texture != null:
   var picture := TextureRect.new()
   picture.texture = texture
   picture.custom_minimum_size = Vector2(0, 190)
   picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
   panel.add_child(picture)
 else:
  _label(("Picture unavailable: " if language == "en" else "تعذر عرض الصورة: ") + str(visible.get("id", "")), 14)
 if bool(state.get("awaiting_confirmation", false)):
  if me != current:
   _label("المنافس ينتظر تأكيد تخمينه")
   _button("التخمين صحيح", func(): _send({"type":"photo_confirm","correct":true}))
   _button("التخمين خطأ", func(): _send({"type":"photo_confirm","correct":false}))
  else:
   _label("بانتظار تأكيد المنافس")
 elif me == current:
  _label(("Your question • remaining: " if language == "en" else "دورك في السؤال • المتبقي: ") + str(state.get("remaining", "?")) + (" seconds" if language == "en" else " ثانية"))
  if not bool(state.get("pending_question", false)):
   _button("🎙 ابدأ السؤال الصوتي", func(): _send({"type":"photo_voice_start"}))
   text_field = _field("اكتب سؤالًا للمنافس")
   _button("إرسال السؤال", func(): _send({"type":"photo_text","text":text_field.text}))
   var facts: Array = state.get("available_questions", [])
   for fact in facts:
    var key := str(fact)
    if FACT_LABELS.has(key):
     _button(str(FACT_LABELS[key]), func(): _send({"type":"photo_tap","question_id":key}))
  else:
   _label("🎙 السؤال جارٍ — بانتظار إجابة المنافس..." if str(state.get("question_mode", "")) == "voice" else "بانتظار إجابة المنافس...")
  guess_field = _field("تخمين الصورة")
  _button("طلب تأكيد التخمين", func(): _send({"type":"photo_guess","guess":guess_field.text}))
  _label("الدور ينتقل تلقائيًا عند انتهاء المؤقت", 15)
 else:
  _label("دور المنافس")
  if bool(state.get("pending_question", false)):
   _button("الإجابة: نعم", func(): _send({"type":"photo_reply","answer":true}))
   _button("الإجابة: لا", func(): _send({"type":"photo_reply","answer":false}))
 _label("اختبار الميكروفون المحلي (لا ينقل الصوت للمنافس)", 15)
 mic_level_label = _label("مستوى الصوت: --", 15)
 _button("تشغيل اختبار الميكروفون", _start_mic_probe)
 _button("إيقاف اختبار الميكروفون", _stop_mic_probe)
 _button("تحديث الحالة", func(): _send({"type":"photo_sync"}))
 _button("مغادرة الغرفة", func(): _send({"type":"photo_leave"}); state = {}; session_code = ""; resume_token = ""; _draw_lobby())

func _home() -> void:
 if connected:
  _send({"type":"photo_leave"})
 _stop_mic_probe()
 socket.close()
 get_tree().change_scene_to_file(HOME)

func _start_mic_probe() -> void:
 if mic_probe == null:
  return
 mic_probe_active = true
 mic_probe.start_probe()
 _status("اختبار الميكروفون المحلي يعمل")

func _stop_mic_probe() -> void:
 mic_probe_active = false
 voice_question_active = false
 if is_instance_valid(mic_probe):
  mic_probe.stop_probe()

func _sync_voice() -> void:
 if not is_instance_valid(mic_probe):
  return
 var mine := int(state.get("player", -1)) == int(state.get("current", -2))
 var should_send := mine and str(state.get("question_mode", "")) == "voice" and bool(state.get("pending_question", false)) and not bool(state.get("awaiting_confirmation", false)) and not bool(state.get("finished", false))
 if should_send and not voice_question_active:
  voice_question_active = true
  mic_probe.start_voice()
 elif not should_send and voice_question_active:
  voice_question_active = false
  mic_probe.stop_voice()
 if is_instance_valid(voice_receiver) and mine and should_send:
  voice_receiver.clear_audio()

func _on_voice_frame(pcm: String) -> void:
 if voice_question_active and connected and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  _send({"type":"photo_voice", "pcm":pcm})

func _on_mic_level(level: float) -> void:
 if mic_probe_active and is_instance_valid(mic_level_label):
  mic_level_label.text = ("Microphone level: %d%%" if language == "en" else "مستوى الصوت: %d%%") % int(clampf(level * 100.0, 0.0, 100.0))

func _invoke_action(ref: WeakRef, generation: int, action: Callable) -> void:
 var control: Variant = ref.get_ref()
 if is_inside_tree() and generation == ui_generation and is_instance_valid(control):
  if control.is_inside_tree() and not control.is_queued_for_deletion():
   action.call()

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST:
  _home.call_deferred()

func _exit_tree() -> void:
 _stop_mic_probe()
 socket.close()

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_BACK]:
  get_viewport().set_input_as_handled()
  _home.call_deferred()

const ENGLISH = {
 "هل هو كائن حي؟": "Is it alive?",
 "هل هو حيوان؟": "Is it an animal?",
 "هل هو شخص مشهور؟": "Is it a celebrity?",
 "هل يمكن أكله؟": "Is it edible?",
 "هل يُستخدم في المنزل؟": "Is it used at home?",
 "هل يوجد في الطبيعة؟": "Is it found in nature?",
 "هل هو مكان؟": "Is it a place?",
 "هل حجمه كبير؟": "Is it large?",
 "🖼️ خمن صورتك — PHOTO DUEL": "🖼️ GUESS YOUR PICTURE — PHOTO DUEL",
 "يتطلب خادم الغرف تفعيل تحدي الصور": "Photo Duel must be enabled on the room server",
 "جاهز": "Ready",
 "عنوان خادم الغرف": "Room server URL",
 "كود الغرفة للانضمام": "Room code to join",
 "إنشاء غرفة": "Create room",
 "الانضمام للغرفة": "Join room",
 "استعادة الجلسة": "Resume session",
 "العودة للقائمة الرئيسية": "Back to main menu",
 "تحديث الحالة": "Refresh state",
 "العودة": "Back",
 "في انتظار دخول اللاعب الثاني...": "Waiting for the second player...",
 "تم إغلاق الغرفة": "Room closed",
 "انتهت المباراة": "Match finished",
 "صورة المنافس (لا تظهر له على جهازه):": "Opponent picture (hidden on their device):",
 "المنافس ينتظر تأكيد تخمينه": "Opponent is waiting for guess confirmation",
 "التخمين صحيح": "Correct guess",
 "التخمين خطأ": "Incorrect guess",
 "بانتظار تأكيد المنافس": "Waiting for opponent confirmation",
 "🎙 ابدأ السؤال الصوتي": "🎙 Start voice question",
 "اكتب سؤالًا للمنافس": "Write a question",
 "إرسال السؤال": "Send question",
 "🎙 السؤال جارٍ — بانتظار إجابة المنافس...": "🎙 Voice question — waiting for reply...",
 "بانتظار إجابة المنافس...": "Waiting for reply...",
 "تخمين الصورة": "Guess the picture",
 "طلب تأكيد التخمين": "Request guess confirmation",
 "الدور ينتقل تلقائيًا عند انتهاء المؤقت": "The turn changes when the timer expires",
 "دور المنافس": "Opponent turn",
 "الإجابة: نعم": "Answer: Yes",
 "الإجابة: لا": "Answer: No",
 "اختبار الميكروفون المحلي (لا ينقل الصوت للمنافس)": "Local microphone test (not sent to opponent)",
 "مستوى الصوت: --": "Microphone level: --",
 "تشغيل اختبار الميكروفون": "Start microphone test",
 "إيقاف اختبار الميكروفون": "Stop microphone test",
 "مغادرة الغرفة": "Leave room",
 "متصل بالسيرفر التجريبي": "Connected to room server",
 "لا يوجد اتصال بالسيرفر": "Not connected",
 "الاتصال جارٍ": "Connecting",
 "عنوان السيرفر يجب أن يبدأ بـ ws:// أو wss://": "Server URL must start with ws:// or wss://",
 "جارٍ الاتصال...": "Connecting...",
 "انقطع الاتصال؛ استخدم استعادة الجلسة": "Disconnected; use Resume session",
 "اختبار الميكروفون المحلي يعمل": "Local microphone test active"
}

func _localized(value: String) -> String:
 return str(ENGLISH.get(value, value)) if language == "en" else value

func _yes_no(value: bool) -> String:
 if language == "en":
  return "Yes" if value else "No"
 return "نعم" if value else "لا"
