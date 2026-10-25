extends Control
## Party Room staging UI. Existing multiplayer and voice remain untouched.
const HOME := "res://scenes/Main.tscn"
var socket := WebSocketPeer.new()
var server_url := "ws://127.0.0.1:8771"
var connected := false
var pending: Dictionary = {}
var code := ""
var player_id := ""
var resume_token := ""
var room_state: Dictionary = {}
var panel: VBoxContainer
var status: Label
var address: LineEdit
var player_name: LineEdit
var join_code: LineEdit
var answer: LineEdit
var last_state := WebSocketPeer.STATE_CLOSED
var page_scroll: ScrollContainer
var saved_scroll_y := 0
var chat_history: Array[String] = []
var draft_round := -2
var draft_text := ""
var draft_strokes: Array = []
var drawing_surface: Control
var countdown_label: Label
var countdown_until := 0

func _ready() -> void:
 _lobby()
 set_process(true)

func _process(_delta: float) -> void:
 if is_instance_valid(countdown_label) and countdown_until > 0:
  countdown_label.text = "الوقت المتبقي: " + str(maxi(0, (countdown_until - Time.get_ticks_msec()) / 1000)) + " ثانية"
 socket.poll()
 var current := socket.get_ready_state()
 if current == WebSocketPeer.STATE_OPEN:
  if not connected:
   connected = true
   _send(pending)
   pending = {}
  while socket.get_available_packet_count() > 0:
   var data: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
   if data is Dictionary:
    _receive(data)
 elif current == WebSocketPeer.STATE_CLOSED and last_state != WebSocketPeer.STATE_CLOSED:
  connected = false
  if is_instance_valid(status):
   _status("انقطع الاتصال. استعد الجلسة من شاشة الاتصال")
 last_state = current

func _send(payload: Dictionary) -> void:
 if socket.get_ready_state() == WebSocketPeer.STATE_OPEN and not payload.is_empty():
  socket.send_text(JSON.stringify(payload))

func _connect(payload: Dictionary) -> void:
 if connected:
  if str(payload.get("type", "")) in ["party.create", "party.join", "party.reconnect"]:
   _status("اتصال موجود بالفعل؛ افتح جلسة جديدة بعد قطع الاتصال")
   return
  _send(payload)
  return
 if socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
  _status("جار الاتصال بالفعل")
  return
 server_url = address.text.strip_edges()
 if not server_url.begins_with("ws://") and not server_url.begins_with("wss://"):
  _status("عنوان السيرفر غير صحيح")
  return
 pending = payload
 socket = WebSocketPeer.new()
 var error := socket.connect_to_url(server_url)
 if error != OK:
  _status("فشل الاتصال: " + str(error))
 else:
  _status("جار الاتصال بالسيرفر التجريبي...")
 last_state = WebSocketPeer.STATE_CONNECTING

func _receive(message: Dictionary) -> void:
 match str(message.get("type", "")):
  "party.auth":
   code = str(message.get("code", ""))
   player_id = str(message.get("player_id", ""))
   resume_token = str(message.get("resume_token", ""))
   _status("تم الاتصال بالغرفة " + code)
  "party.state":
   room_state = message.get("state", {})
   var remaining: Variant = room_state.get("remaining")
   countdown_until = Time.get_ticks_msec() + int(remaining) * 1000 if remaining != null else 0
   _room()
  "party.chat":
   chat_history.append(str(message.get("name", "")) + ": " + str(message.get("text", "")))
   if chat_history.size() > 10:
    chat_history.pop_front()
   _room()
  "party.error":
   _status("خطأ: " + str(message.get("error", "")))

func _clear(keep_position: bool = false) -> void:
 var previous_y := page_scroll.scroll_vertical if keep_position and is_instance_valid(page_scroll) else 0
 for child in get_children():
  remove_child(child)
  child.queue_free()
 var scroll := preload("res://scripts/touch_scroll.gd").new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.scroll_deadzone = 12
 scroll.follow_focus = true
 scroll.mouse_filter = Control.MOUSE_FILTER_PASS
 add_child(scroll)
 page_scroll = scroll
 if keep_position:
  saved_scroll_y = previous_y
  _restore_scroll.call_deferred()
 var margin := MarginContainer.new()
 margin.add_theme_constant_override("margin_left", 16)
 margin.add_theme_constant_override("margin_right", 16)
 margin.add_theme_constant_override("margin_top", 16)
 margin.add_theme_constant_override("margin_bottom", 16)
 scroll.add_child(margin)
 panel = VBoxContainer.new()
 panel.add_theme_constant_override("separation", 10)
 margin.add_child(panel)
 _label("🎉 حفلات الأصدقاء", 26)
 _label("6 لاعبين • 8 ألعاب • 15 جولة", 15)
 status = _label("جاهز", 16)

func _restore_scroll() -> void:
 if is_instance_valid(page_scroll):
  page_scroll.scroll_vertical = saved_scroll_y

func _label(value: String, size: int = 19) -> Label:
 var item := Label.new()
 item.text = value
 item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 item.add_theme_font_size_override("font_size", size)
 panel.add_child(item)
 return item

func _field(hint: String, value: String = "") -> LineEdit:
 var item := LineEdit.new()
 item.placeholder_text = hint
 item.text = value
 item.custom_minimum_size.y = 52
 panel.add_child(item)
 return item

func _button(value: String, action: Callable) -> void:
 var item := Button.new()
 item.text = value
 item.custom_minimum_size.y = 54
 item.pressed.connect(action)
 panel.add_child(item)

func _status(value: String) -> void:
 if is_instance_valid(status):
  status.text = value
 print("[PARTY_STAGING] ", value)

func _lobby() -> void:
 _clear()
 address = _field("عنوان WebSocket التجريبي", server_url)
 player_name = _field("اسم اللاعب", "Player")
 join_code = _field("كود الغرفة", code)
 _button("إنشاء غرفة", func(): _connect({"type":"party.create", "name":player_name.text.strip_edges()}))
 _button("الانضمام بكود", func(): _connect({"type":"party.join", "name":player_name.text.strip_edges(), "code":join_code.text.strip_edges().to_upper()}))
 _button("استعادة الجلسة", func(): _connect({"type":"party.reconnect", "code":join_code.text.strip_edges().to_upper(), "player_id":player_id, "resume_token":resume_token}))
 _button("العودة للرئيسية", func(): get_tree().change_scene_to_file(HOME))

func _room() -> void:
 if draft_round == int(room_state.get("round_index", -1)):
  if is_instance_valid(answer):
   draft_text = answer.text
  if is_instance_valid(drawing_surface):
   draft_strokes = drawing_surface.strokes.duplicate(true)
 else:
  draft_text = ""
  draft_strokes.clear()
 draft_round = int(room_state.get("round_index", -1))
 answer = null
 drawing_surface = null
 _clear(true)
 countdown_label = _label("", 17)
 var phase := str(room_state.get("phase", "lobby"))
 _label("كود الغرفة: " + code, 25)
 _label("الحالة: " + phase + " | الجولة: " + str(int(room_state.get("round_index", -1)) + 1) + " / 15")
 _label("اللعبة: " + str(room_state.get("game", "لم تبدأ")))
 var challenge: Dictionary = room_state.get("challenge", {})
 _label(str(challenge.get("prompt", "")), 21)
 if challenge.has("choices"):
  _label(str(challenge["choices"]), 18)
 if room_state.get("private_task") != null:
  _label("مهمتك: " + str(room_state["private_task"]), 20)
 _label("النقاط: " + str(room_state.get("scores", {})), 17)
 var rule: Dictionary = room_state.get("round_rule", {}) if room_state.get("round_rule", {}) is Dictionary else {}
 if not rule.is_empty():
  _label(str(rule.get("title_ar", "")) + " — " + str(rule.get("instruction_ar", "")), 17)
 var reveal_data: Dictionary = room_state.get("reveal", {}) if room_state.get("reveal", {}) is Dictionary else {}
 if phase == "reveal" and not reveal_data.is_empty():
  _label("الإجابات: " + str(reveal_data.get("answers", {})), 16)
  _label("النقاط المضافة: " + str(reveal_data.get("awarded", {})), 16)
 if phase == "results":
  _label("النتيجة النهائية: " + str(room_state.get("scores", {})), 20)
 var members: Array = room_state.get("members", [])
 for member in members:
  if member is Dictionary:
   _label(str(member.get("name", "")) + (" ✓" if member.get("ready", false) else " …"), 16)
 if phase == "lobby":
  _button("أنا مستعد", func(): _send({"type":"party.ready", "ready":true}))
  if player_id == str(room_state.get("host_id", "")):
   _button("بدء المباراة", func(): _send({"type":"party.start"}))
 elif phase == "active" and room_state.get("my_submission") != null:
  _label("تم إرسال إجابتك؛ انتظر باقي اللاعبين")
  if str(room_state.get("game", "")) == "truth_or_dare" and not room_state.get("my_completed", false):
   _button("نفذت المهمة", func(): _send({"type":"party.complete"}))
  if player_id == str(room_state.get("host_id", "")):
   _button("كشف الإجابات", func(): _send({"type":"party.reveal"}))
 elif phase == "active":
  var kind := str(rule.get("answer_kind", "text"))
  if str(room_state.get("game", "")) == "pass_the_bomb" and str(room_state.get("bomb_player", "")) != player_id:
   _label("القنبلة مع اللاعب: " + str(room_state.get("bomb_player", "")))
  elif kind == "drawing":
   var canvas := preload("res://scripts/party_drawing.gd").new()
   canvas.strokes = draft_strokes.duplicate(true)
   drawing_surface = canvas
   panel.add_child(canvas)
   _button("مسح الرسم", func(): canvas.strokes.clear(); canvas.queue_redraw())
   _button("إرسال الرسم", func(): _send({"type":"party.submit", "answer":canvas.payload(), "request_id":str(Time.get_ticks_usec())}))
  elif kind == "player_vote":
   _label("صوّت للاعب من الموجودين في الغرفة", 15)
   var selector := OptionButton.new()
   for member in members:
    if member is Dictionary:
     selector.add_item(str(member.get("name", "Player")))
     selector.set_item_metadata(selector.item_count - 1, str(member.get("id", "")))
   panel.add_child(selector)
   _button("إرسال التصويت", func(): _send({"type":"party.submit", "answer":str(selector.get_selected_metadata()), "request_id":str(Time.get_ticks_usec())}))
  elif kind in ["choice", "truth_dare", "completion"]:
   var choices := ["A", "B", "C", "D"] if kind == "choice" else (["truth", "dare"] if kind == "truth_dare" else ["done", "skip"])
   var selector := OptionButton.new()
   for choice in choices:
    selector.add_item(choice)
   panel.add_child(selector)
   _button("إرسال الاختيار", func(): _send({"type":"party.submit", "answer":selector.get_item_text(selector.selected), "request_id":str(Time.get_ticks_usec())}))
  else:
   answer = _field("إجابتك لهذه الجولة", draft_text)
   _button("إرسال الإجابة", func(): _send({"type":"party.submit", "answer":answer.text, "request_id":str(Time.get_ticks_usec())}))
  if player_id == str(room_state.get("host_id", "")):
   _button("كشف الإجابات", func(): _send({"type":"party.reveal"}))
 elif phase == "voting":
  _label("صوّت لاختيار منافس؛ لا يمكن التصويت لنفسك")
  var options: Dictionary = reveal_data.get("options", {})
  if not room_state.get("has_voted", false):
   for option_id in options:
    var chosen: String = str(option_id)
    if str(room_state.get("game", "")) == "draw_disaster":
     var canvas := preload("res://scripts/party_drawing.gd").new()
     canvas.read_only = true
     var decoded: Variant = JSON.parse_string(str(options[option_id]))
     canvas.strokes = decoded if decoded is Array else []
     panel.add_child(canvas)
    else:
     _label(str(options[option_id]), 18)
    _button("اختيار", func(): _send({"type":"party.vote", "option":chosen}))
  if player_id == str(room_state.get("host_id", "")):
   _button("إنهاء التصويت", func(): _send({"type":"party.finish_votes"}))
 elif phase == "reveal" and player_id == str(room_state.get("host_id", "")):
  if str(room_state.get("game", "")) in ["truth_or_dare", "secret_mission"]:
   for member in members:
    var reviewed: String = str(member.get("id", ""))
    _button("تأكيد إتمام: " + str(member.get("name", "")), func(): _send({"type":"party.approve", "player_id":reviewed}))
  _button("الجولة التالية", func(): _send({"type":"party.next"}))
 elif phase == "results":
  _label("انتهت الجولات الخمس عشرة")
 for line in chat_history:
  _label(line, 15)
 var chat := _field("رسالة اختيارية للأصدقاء")
 _button("إرسال الرسالة", func(): _send({"type":"party.chat", "text":chat.text}))
 _button("تحديث الحالة", func(): _send({"type":"party.state"}))
 _button("رجوع لشاشة الاتصال", _lobby)
