extends Control
## Staging-only Photo Duel client. Open res://scenes/PhotoDuelStaging.tscn in Godot.
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
var server_url := "ws://127.0.0.1:8769"
var previous_state := WebSocketPeer.STATE_CLOSED
var mic_probe: Node
var mic_level_label: Label
var mic_probe_active := false
var voice_receiver: Node
var voice_question_active := false

func _ready() -> void:
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
  _status("تعذر بدء الاتصال: " + str(err))
 else:
  _status("جارٍ الاتصال...")
 previous_state = WebSocketPeer.STATE_CONNECTING

func _received(message: Dictionary) -> void:
 var kind := str(message.get("type", ""))
 match kind:
  "photo_created", "photo_joined", "photo_resumed":
   session_code = str(message.get("code", session_code))
   resume_token = str(message.get("token", ""))
   _status("غرفة " + session_code + " • الجلسة متصلة")
   _draw_match()
  "photo_waiting":
   _status("في انتظار اللاعب الثاني • كود الغرفة: " + session_code)
  "photo_state":
   state = message
   _draw_match()
   _sync_voice()
  "photo_voice":
   if is_instance_valid(voice_receiver):
    voice_receiver.receive_pcm(str(message.get("pcm", "")))
  "photo_error":
   _status("خطأ: " + str(message.get("message", "غير معروف")))
  "photo_question", "photo_reply", "photo_turn", "photo_guess_pending", "photo_guess_result", "photo_finished":
   _status("حدث: " + kind)
  _:
   pass

func _clear() -> void:
 for child in get_children():
  if child == mic_probe or child == voice_receiver:
   continue
  remove_child(child)
  child.queue_free()
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
 _label("اختبار شبكي معزول • ليس سيرفر الإنتاج", 15)
 status_label = _label("جاهز", 16)

func _label(value: String, size: int = 19) -> Label:
 var label_node := Label.new()
 label_node.text = value
 label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label_node.add_theme_font_size_override("font_size", size)
 panel.add_child(label_node)
 return label_node

func _field(placeholder: String, value: String = "") -> LineEdit:
 var field := LineEdit.new()
 field.placeholder_text = placeholder
 field.text = value
 field.custom_minimum_size.y = 55
 panel.add_child(field)
 return field

func _button(value: String, callback: Callable) -> void:
 var b := Button.new()
 b.text = value
 b.custom_minimum_size.y = 54
 b.pressed.connect(callback)
 panel.add_child(b)

func _status(value: String) -> void:
 if is_instance_valid(status_label):
  status_label.text = value
 print("[PHOTO_STAGING] ", value)

func _draw_lobby() -> void:
 _stop_mic_probe()
 _clear()
 address_field = _field("WebSocket staging URL", server_url)
 code_field = _field("كود الغرفة للانضمام", session_code)
 _button("إنشاء غرفة", func(): _connect_and_send({"type":"photo_create","target":10,"timer":30,"reward":1}))
 _button("الانضمام للغرفة", func(): _connect_and_send({"type":"photo_join","code":code_field.text.strip_edges().to_upper()}))
 _button("استعادة الجلسة", func(): _connect_and_send({"type":"photo_resume","code":code_field.text.strip_edges().to_upper(),"token":resume_token}))
 _button("العودة للقائمة الرئيسية", _home)

func _draw_match() -> void:
 _stop_mic_probe()
 _clear()
 _label("كود الغرفة: " + session_code)
 if state.is_empty():
  _label("في انتظار دخول اللاعب الثاني...")
  _button("تحديث الحالة", func(): _send({"type":"photo_sync"}))
  _button("العودة", _draw_lobby)
  return
 var me := int(state.get("player", -1))
 var current := int(state.get("current", -1))
 var scores: Array = state.get("scores", [0, 0])
 _label("اللاعب %d | الجولة %d | النقاط %s" % [me + 1, int(state.get("round", 1)), str(scores)])
 if bool(state.get("closed", false)):
  _label("تم إغلاق الغرفة")
  _button("العودة", _draw_lobby)
  return
 if bool(state.get("finished", false)):
  _label("انتهت المباراة")
  _button("العودة", _draw_lobby)
  return
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
  _label("تعذر عرض الصورة: " + str(visible.get("id", "")), 14)
 if bool(state.get("awaiting_confirmation", false)):
  if me != current:
   _label("المنافس ينتظر تأكيد تخمينه")
   _button("التخمين صحيح", func(): _send({"type":"photo_confirm","correct":true}))
   _button("التخمين خطأ", func(): _send({"type":"photo_confirm","correct":false}))
  else:
   _label("بانتظار تأكيد المنافس")
 elif me == current:
  _label("دورك في السؤال • المتبقي: " + str(state.get("remaining", "?")) + " ثانية")
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
   _label("🎙 السؤال جارٍ — بانتظار إجابة المنافس...")
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
 var should_send := mine and bool(state.get("pending_question", false)) and not bool(state.get("awaiting_confirmation", false)) and not bool(state.get("finished", false))
 if should_send:
  voice_question_active = true
  mic_probe.start_voice()
 else:
  voice_question_active = false
  mic_probe.stop_voice()
  if is_instance_valid(voice_receiver):
   voice_receiver.clear_audio()

func _on_voice_frame(pcm: String) -> void:
 if voice_question_active and connected and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  _send({"type":"photo_voice", "pcm":pcm})

func _on_mic_level(level: float) -> void:
 if mic_probe_active and is_instance_valid(mic_level_label):
  mic_level_label.text = "مستوى الصوت: %d%%" % int(clampf(level * 100.0, 0.0, 100.0))
