extends Control

const VisualSkin = preload("res://scripts/visual_skin.gd")
const VoiceSignalingBridge = preload("res://scripts/voice_signaling_bridge.gd")
const VoiceMicrophoneCapture = preload("res://scripts/voice_microphone_capture.gd")
const VoicePCMTransport = preload("res://scripts/voice_pcm_transport.gd")

const BG := Color("0b1027")
const PANEL := Color("19234b")
var socket := WebSocketPeer.new()
var connected := false
var room_code := ""
var opponent_card := ""
var questions: Array = []
var my_turn := false
var finished := false
var output: VBoxContainer
var address_input: LineEdit
var code_input: LineEdit
var guess_input: LineEdit
var action_area: VBoxContainer
var card_art: TextureRect
var status: Label
var language: String = "ar"
var ui_tr: Dictionary = {}
var ui_ar: Dictionary = {}
var catalog: Dictionary = {}
var localized_questions: Dictionary = {}
var share_button: Button
var language_button: Button
var art_style: String = "realistic"
var reduced_motion: bool = false
var audience: String = ""
# Set the production WSS endpoint in res://data/network_config.json.
# Local LAN testing can use ws:// only via Advanced settings.
var server_url: String = ""
var pending_action: Dictionary = {}
var advanced_panel: VBoxContainer
var connection_button: Button
var join_button: Button
var create_button: Button
var match_button: Button
var network_ready := false
var connect_started_ms: int = 0
const CONNECT_TIMEOUT_MS: int = 60000
var matchmaking_pending := false
var action_in_flight := false
# Server is authoritative: a timed-out move is NOT retried automatically.
# Moves are never resent automatically; sync/resume rebuild state from server history.
var lobby_request_pending := false
var leaving := false
var lobby_request_started_ms: int = 0
var move_started_ms: int = 0
var leave_started_ms: int = 0
const SERVER_REPLY_TIMEOUT_MS: int = 20000
const LEAVE_ACK_TIMEOUT_MS: int = 12000
# Sync first on a lost move reply; only reconnect if the sync also times out.
const SYNC_TIMEOUT_MS: int = 6500
const PING_INTERVAL_MS: int = 12000
const PONG_TIMEOUT_MS: int = 25000
var sync_pending := false
var sync_started_ms: int = 0
var ping_waiting := false
var ping_sent_ms: int = 0
var last_ping_ms: int = 0
var latency_ms: int = -1
var health_label: Label
const RECONNECT_WINDOW_MS: int = 85000
const RECONNECT_ATTEMPT_MS: int = 8000
var resume_token: String = ""
var reconnecting := false
var reconnect_pending := false
var reconnect_deadline_ms: int = 0
var reconnect_next_ms: int = 0
var opponent_paused := false
var match_view: VBoxContainer
var voice_button: Button
var voice_status: Label
var voice_invite_dialog: ConfirmationDialog
var voice_opted_in := false
var peer_voice_opted_in := false
var voice_request_pending := false
var voice_request_started_ms: int = 0
const VOICE_REQUEST_TIMEOUT_MS: int = 12000
var voice_signaling = VoiceSignalingBridge.new()
var voice_microphone = VoiceMicrophoneCapture.new()
var voice_transport = VoicePCMTransport.new()
var voice_transport_started := false
var voice_permission_requested := false
var voice_capture_failed := false
var voice_retry_after_ms := 0
var voice_level := 0.0
var voice_last_meter_ms: int = 0
var voice_sent_packets: int = 0
var voice_received_packets: int = 0
var voice_capture_frames: int = 0
var voice_capture_started_ms: int = 0
var lobby_controls: VBoxContainer
var match_label: Label
var question_page: int = 0
const QUESTIONS_PER_PAGE: int = 6
# The local deduction board never receives the player's secret from the server.
# It only filters the public 24-card catalog using yes/no replies to this player's questions.
var possible_cards: Array = []
var asked_questions: Array[int] = []
var candidate_page: int = 0
const CANDIDATES_PER_PAGE: int = 6


func _t(ar: String, en: String) -> String:
 return ar if language == "ar" else _local(en)

func _ready() -> void:
 voice_signaling.configure(Callable(self, "_voice_signal_send"))
 ui_tr = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"))
 ui_ar = JSON.parse_string(FileAccess.get_file_as_string("res://data/online_ar.json"))
 catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
 var preferences: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://audience_preferences.json")) if FileAccess.file_exists("user://audience_preferences.json") else null
 if preferences is Dictionary:
  audience = str(preferences.get("audience", ""))
 if audience != "all":
  audience = "all"
 var saved_path: String = "user://progress_v10_" + audience + ".json"
 var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(saved_path)) if FileAccess.file_exists(saved_path) else null
 if saved is Dictionary:
  art_style = str(saved.get("art_style", "realistic"))
  reduced_motion = bool(saved.get("reduced_motion", false))
  language = str(saved.get("language", "ar"))
 if language not in ["ar", "en"]:
  language = "ar"
 var bg := VisualSkin.new()
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(bg)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.scroll_deadzone = 22
 scroll.follow_focus = true
 add_child(scroll)
 output = VBoxContainer.new()
 output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 output.add_theme_constant_override("separation", 12)
 var margin := MarginContainer.new()
 margin.add_theme_constant_override("margin_left", 16)
 margin.add_theme_constant_override("margin_right", 16)
 margin.add_theme_constant_override("margin_top", 12)
 margin.add_theme_constant_override("margin_bottom", 24)
 margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(margin)
 margin.add_child(output)
 VisualSkin.add_hero(output, _t("🎭 خمن صورتك", "🎭 GUESS YOUR PICTURE"), _t("العب مع صاحبك واكشف صورتك السرية", "Play with a friend. Discover your secret picture."), _t("ساحة الأصدقاء", "FRIENDS ARENA"))
 var lobby_brand := TextureRect.new()
 lobby_brand.texture = load("res://assets/ui/gaming_hub_brand.png") as Texture2D
 lobby_brand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 lobby_brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 lobby_brand.custom_minimum_size.y = 125
 output.add_child(lobby_brand)
 language_button = Button.new()
 language_button.text = "العربية / English"
 language_button.custom_minimum_size.y = 52
 language_button.pressed.connect(_toggle_language)
 VisualSkin.decorate_button(language_button, "secondary")
 output.add_child(language_button)
 var network_settings: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/network_config.json"))
 if network_settings is Dictionary:
  server_url = str(network_settings.get("server_url", "")).strip_edges()
 _label(_t("العب مع صاحبك بكود غرفة أو اختار منافس عشوائي.", "Play a friend using a room code or find a random opponent."), 17)
 # The active match is placed ABOVE lobby actions for portrait phones.
 status = _label(_t("جاهز للاتصال", "Ready to connect"), 18)
 health_label = _label(_t("الشبكة: غير متصل", "Network: offline"), 14)
 health_label.add_theme_color_override("font_color", Color("a7b6d7"))
 match_view = VBoxContainer.new()
 match_view.add_theme_constant_override("separation", 10)
 output.add_child(match_view)
 match_label = Label.new()
 match_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 match_label.add_theme_font_size_override("font_size", 19)
 match_label.add_theme_color_override("font_color", Color.WHITE)
 match_view.add_child(match_label)
 action_area = VBoxContainer.new()
 action_area.add_theme_constant_override("separation", 8)
 match_view.add_child(action_area)
 lobby_controls = VBoxContainer.new()
 lobby_controls.add_theme_constant_override("separation", 10)
 output.add_child(lobby_controls)
 create_button = Button.new()
 create_button.text = _t("إنشاء غرفة لصديق", "Create a friend room")
 create_button.custom_minimum_size.y = 64
 create_button.pressed.connect(func(): _request_action({"type":"create"}))
 _style_button(create_button, true)
 lobby_controls.add_child(create_button)
 code_input = _text_input("كود الغرفة - 6 حروف أو أرقام")
 code_input.reparent(lobby_controls)
 code_input.max_length = 6
 code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
 join_button = Button.new()
 join_button.text = _t("انضمام بكود", "Join with code")
 join_button.custom_minimum_size.y = 64
 join_button.pressed.connect(_join_room)
 _style_button(join_button)
 lobby_controls.add_child(join_button)
 match_button = Button.new()
 match_button.text = _t("منافس عشوائي", "Find an opponent")
 match_button.custom_minimum_size.y = 64
 match_button.pressed.connect(func(): _request_action({"type":"matchmake"}))
 _style_button(match_button, true)
 lobby_controls.add_child(match_button)
 share_button = Button.new()
 share_button.text = _t("نسخ دعوة الغرفة", "Copy room invitation")
 share_button.custom_minimum_size.y = 52
 share_button.disabled = true
 share_button.pressed.connect(_copy_invite)
 _style_button(share_button)
 lobby_controls.add_child(share_button)
 _button(_t("إلغاء البحث / مغادرة الغرفة", "Cancel / Leave room"), _leave_match)
 var advanced_toggle := Button.new()
 advanced_toggle.text = _t("إعدادات الاتصال (متقدمة)", "Connection settings (advanced)")
 VisualSkin.decorate_button(advanced_toggle, "secondary")
 advanced_toggle.pressed.connect(func(): advanced_panel.visible = not advanced_panel.visible)
 output.add_child(advanced_toggle)
 advanced_panel = VBoxContainer.new()
 advanced_panel.visible = false
 output.add_child(advanced_panel)
 address_input = LineEdit.new()
 address_input.placeholder_text = "wss://game.example.com  /  ws://LAN-IP:8765"
 address_input.text = server_url
 address_input.custom_minimum_size.y = 52
 advanced_panel.add_child(address_input)
 _button(_t("اتصال يدوي", "Connect manually"), _connect_server, advanced_panel)
 _button(_t("العودة للألعاب", "Back to games"), _request_exit_to_games)
 _update_lobby()

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
   get_viewport().set_input_as_handled()
   _request_exit_to_games()

func _request_exit_to_games() -> void:
 if room_code.is_empty() and not matchmaking_pending and pending_action.is_empty() and not lobby_request_pending and not leaving:
  _exit_to_games()
  return
 var dialog := ConfirmationDialog.new()
 dialog.title = _t("مغادرة الأونلاين؟", "LEAVE ONLINE GAME?")
 dialog.dialog_text = _t("سيتم إلغاء البحث أو مغادرة الغرفة الحالية.", "Matchmaking will be cancelled or you will leave your current room.")
 dialog.ok_button_text = _t("مغادرة", "LEAVE")
 dialog.cancel_button_text = _t("متابعة", "STAY")
 add_child(dialog)
 dialog.confirmed.connect(_exit_to_games)
 dialog.popup_centered(Vector2i(360, 180))
 dialog.visibility_changed.connect(func() -> void:
  if not dialog.visible:
   dialog.queue_free()
 )

func _exit_to_games() -> void:
 if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  _send({"type": "cancel_queue"})
  _send({"type": "leave"})
  socket.poll()
 socket.close()
 pending_action.clear()
 get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _label(value: String, size: int = 20) -> Label:
 var l := Label.new()
 l.text = _local(value)
 l.set_meta("ui_source", value)
 l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size", size)
 l.add_theme_color_override("font_color", Color.WHITE)
 output.add_child(l)
 return l

func _text_input(hint: String) -> LineEdit:
 var i := LineEdit.new()
 i.placeholder_text = _local(hint)
 i.set_meta("ui_hint", hint)
 i.custom_minimum_size.y = 52
 VisualSkin.decorate_input(i)
 output.add_child(i)
 return i

func _button(value: String, callback: Callable, parent: VBoxContainer = null) -> void:
 var b := Button.new()
 b.text = _local(value)
 b.set_meta("ui_source", value)
 b.custom_minimum_size.y = 52
 b.pressed.connect(callback)
 _style_button(b)
 var target: VBoxContainer = parent if parent != null else output
 target.add_child(b)

func _style_button(button: Button, primary: bool = false) -> void:
 VisualSkin.decorate_button(button, "violet" if primary else "secondary")
 button.button_down.connect(func() -> void:
  if not reduced_motion and not button.disabled:
   button.pivot_offset = button.size * 0.5
   var animation := button.create_tween()
   animation.tween_property(button, "scale", Vector2(0.98, 0.98), 0.06)
 )
 button.button_up.connect(func() -> void:
  if not reduced_motion:
   var animation := button.create_tween()
   animation.tween_property(button, "scale", Vector2.ONE, 0.09)
 )
 button.pressed.connect(func() -> void:
  if OS.get_name() == "Android":
   Input.vibrate_handheld(12)
 )

func _clear_match_view() -> void:
 if not is_instance_valid(match_view):
  return
 for child in match_view.get_children():
  if child != action_area and child != match_label:
   child.queue_free()
 match_label.text = ""
 deduction_status = null

func _update_lobby() -> void:
 if not is_instance_valid(lobby_controls):
  return
 var active := not room_code.is_empty() or matchmaking_pending or not pending_action.is_empty() or lobby_request_pending or leaving
 create_button.disabled = active
 join_button.disabled = active
 match_button.disabled = active
 code_input.editable = not active
 share_button.disabled = room_code.is_empty() or leaving

func _reset_match_state() -> void:
 sync_pending = false
 sync_started_ms = 0
 ping_waiting = false
 ping_sent_ms = 0
 last_ping_ms = 0
 latency_ms = -1
 if is_instance_valid(health_label):
  health_label.text = _t("الشبكة: غير متصل", "Network: offline")
 room_code = ""
 opponent_card = ""
 questions.clear()
 localized_questions.clear()
 my_turn = false
 finished = true
 player_index = -1
 matchmaking_pending = false
 action_in_flight = false
 resume_token = ""
 reconnecting = false
 reconnect_pending = false
 reconnect_deadline_ms = 0
 reconnect_next_ms = 0
 opponent_paused = false
 lobby_request_pending = false
 leaving = false
 lobby_request_started_ms = 0
 move_started_ms = 0
 leave_started_ms = 0
 possible_cards.clear()
 asked_questions.clear()
 candidate_page = 0
 if is_instance_valid(action_area):
  _refresh_actions()
 _clear_match_view()
 _update_lobby()

func _join_room() -> void:
 var code := code_input.text.strip_edges().to_upper()
 if code.length() != 6:
  status.text = _t("كود الغرفة لازم يكون 6 حروف أو أرقام", "Room code must be 6 characters")
  return
 _request_action({"type":"join", "code":code})

func _leave_match() -> void:
 if leaving:
  return
 if reconnecting:
  socket.close()
  socket = WebSocketPeer.new()
  _reset_match_state()
  status.text = _t("تم إلغاء محاولة الاستكمال", "Reconnection cancelled")
  return
 pending_action.clear()
 matchmaking_pending = false
 # A cancel while Render is waking up must not start a room later.
 if socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
  socket.close()
  socket = WebSocketPeer.new()
  connect_started_ms = 0
  connected = false
  _reset_match_state()
  status.text = _t("تم إلغاء الاتصال", "Connection cancelled")
  return
 if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  # One authoritative leave acknowledgement resets the room/queue.
  # Ignore any older room/started packets received before that acknowledgement.
  leaving = true
  leave_started_ms = Time.get_ticks_msec()
  lobby_request_pending = false
  lobby_request_started_ms = 0
  move_started_ms = 0
  action_in_flight = false
  _update_lobby()
  _send({"type":"leave"})
  if leaving:
   status.text = _t("جاري مغادرة الغرفة...", "Leaving room...")
 else:
  _reset_match_state()
  status.text = _t("لا توجد مباراة نشطة", "No active match")

func _request_action(message: Dictionary) -> void:
 if not pending_action.is_empty() or matchmaking_pending or not room_code.is_empty() or lobby_request_pending or leaving:
  return
 if audience == "children":
  status.text = _t("ملف الأطفال يستخدم اللعب المحلي", "Children’s profile uses local play")
  return
 if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  lobby_request_pending = true
  lobby_request_started_ms = Time.get_ticks_msec()
  matchmaking_pending = str(message.get("type", "")) == "matchmake"
  _update_lobby()
  _send(message)
  return
 if socket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
  # Only one lobby action may be pending; a second tap cannot overwrite it.
  if not pending_action.is_empty():
   return
  pending_action = message.duplicate()
  _update_lobby()
  status.text = _t("جاري الاتصال، انتظر لحظة...", "Connecting, please wait...")
  return
 pending_action = message.duplicate()
 _connect_server()
 _update_lobby()

func _connect_server() -> void:
 if audience == "children":
  status.text = _t("ملف الأطفال يستخدم اللعب المحلي", "Children’s profile uses local play")
  pending_action.clear()
  return
 var url := address_input.text.strip_edges()
 if url.is_empty():
  status.text = _t("الأونلاين يحتاج سيرفر WSS منشور. افتح إعدادات الاتصال.", "Online requires a deployed WSS server. Open connection settings.")
  pending_action.clear()
  return
 if not (url.begins_with("wss://") or url.begins_with("ws://")):
  status.text = _t("عنوان السيرفر غير صحيح", "Invalid server URL")
  pending_action.clear()
  return
 # Preserve the requested lobby action across the local state reset.
 # Previously _reset_match_state() called _update_lobby() before connecting,
 # and the queued action was silently lost when a new connection was opened.
 var queued_action: Dictionary = pending_action.duplicate()
 if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
  socket.close()
 connected = false
 _reset_match_state()
 pending_action = queued_action
 _update_lobby()
 connect_started_ms = Time.get_ticks_msec()
 socket = WebSocketPeer.new()
 var err := socket.connect_to_url(url)
 if err != OK:
  pending_action.clear()
  _update_lobby()
 status.text = _t("جاري الاتصال...", "Connecting...") if err == OK else _t("فشل بدء الاتصال: ", "Connection error: ") + str(err)

func _start_reconnect() -> void:
 sync_pending = false
 sync_started_ms = 0
 ping_waiting = false
 ping_sent_ms = 0
 if is_instance_valid(health_label):
  health_label.text = _t("الشبكة: جاري الاستعادة", "Network: reconnecting")
 if reconnecting or resume_token.is_empty() or room_code.is_empty() or finished or leaving:
  return
 socket.close()
 socket = WebSocketPeer.new()
 connected = false
 action_in_flight = false
 move_started_ms = 0
 reconnecting = true
 reconnect_pending = false
 reconnect_deadline_ms = Time.get_ticks_msec() + RECONNECT_WINDOW_MS
 reconnect_next_ms = Time.get_ticks_msec() + 700
 connect_started_ms = 0
 _refresh_actions()
 status.text = _t("انقطع الاتصال؛ جاري استكمال نفس المباراة...", "Connection lost; restoring your match...")

func _process(_delta: float) -> void:
 socket.poll()
 if voice_signaling.ready() and not voice_microphone.is_capturing() and _voice_permission_granted() and Time.get_ticks_msec() >= voice_retry_after_ms:
  _sync_voice_microphone()
  _update_voice_ui()
 if voice_microphone.is_capturing() and (not voice_signaling.ready() or socket.get_ready_state() != WebSocketPeer.STATE_OPEN):
  voice_microphone.stop()
  voice_transport.stop()
  voice_transport_started = false
  voice_level = 0.0
  _update_voice_ui()
 if voice_microphone.is_capturing():
  _poll_voice_microphone()
 if voice_transport_started:
  voice_transport.pump()
  _refresh_voice_diagnostics()
 if voice_request_pending and voice_request_started_ms > 0 and Time.get_ticks_msec() - voice_request_started_ms > VOICE_REQUEST_TIMEOUT_MS:
  voice_request_pending = false
  voice_request_started_ms = 0
  _update_voice_ui()
  if is_instance_valid(voice_status):
   voice_status.text = _t("انتهت مهلة طلب الصوت؛ حاول مرة أخرى.", "Voice request timed out; please try again.")
 var state := socket.get_ready_state()
 if reconnecting:
  var reconnect_now: int = Time.get_ticks_msec()
  if reconnect_now >= reconnect_deadline_ms:
   _abort_stalled_session(_t("انتهت مهلة استكمال المباراة؛ يمكنك بدء مباراة جديدة.", "Reconnection window expired. Start a new match."))
   return
  if reconnect_pending and reconnect_now - connect_started_ms > SERVER_REPLY_TIMEOUT_MS:
   socket.close()
   socket = WebSocketPeer.new()
   reconnect_pending = false
   reconnect_next_ms = reconnect_now + 1500
   connect_started_ms = 0
   return
  if state == WebSocketPeer.STATE_CONNECTING and connect_started_ms > 0 and reconnect_now - connect_started_ms > RECONNECT_ATTEMPT_MS:
   socket.close()
   socket = WebSocketPeer.new()
   reconnect_next_ms = reconnect_now + 1500
   connect_started_ms = 0
   return
  if state == WebSocketPeer.STATE_CLOSED and reconnect_pending:
   reconnect_pending = false
   connected = false
   connect_started_ms = 0
   reconnect_next_ms = reconnect_now + 1500
   return
  if state == WebSocketPeer.STATE_CLOSED and reconnect_now >= reconnect_next_ms:
   socket = WebSocketPeer.new()
   var err := socket.connect_to_url(address_input.text.strip_edges())
   connect_started_ms = reconnect_now if err == OK else 0
   reconnect_next_ms = reconnect_now + 2500
   return
  if state == WebSocketPeer.STATE_OPEN and not reconnect_pending:
   reconnect_pending = true
   connect_started_ms = reconnect_now
   _send({"type":"resume", "code":room_code, "token":resume_token})
  if state != WebSocketPeer.STATE_OPEN:
   return

 if state == WebSocketPeer.STATE_CONNECTING and connect_started_ms > 0 and Time.get_ticks_msec() - connect_started_ms > CONNECT_TIMEOUT_MS:
  socket.close()
  socket = WebSocketPeer.new()
  pending_action.clear()
  connect_started_ms = 0
  matchmaking_pending = false
  _reset_match_state()
  _update_lobby()
  status.text = _t("انتهت مهلة الاتصال. قد يحتاج السيرفر المجاني دقيقة للاستيقاظ. حاول مجددًا.", "Connection timed out. The free server may be waking up. Try again.")
  return
 if state == WebSocketPeer.STATE_OPEN:
  # Read all queued replies BEFORE checking timeouts. On a busy Android frame,
  # a pong may already be received but the old order would discard the room.
  while socket.get_available_packet_count() > 0:
   var early_packet: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
   if early_packet is Dictionary:
    _handle(early_packet)
  if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
   return
  var now_ms: int = Time.get_ticks_msec()
  if leaving and leave_started_ms > 0 and now_ms - leave_started_ms > LEAVE_ACK_TIMEOUT_MS:
   _abort_stalled_session(_t("تعذر تأكيد المغادرة. تم قطع الاتصال بأمان.", "Leave acknowledgement timed out. Connection closed safely."))
   return
  if lobby_request_pending and lobby_request_started_ms > 0 and now_ms - lobby_request_started_ms > SERVER_REPLY_TIMEOUT_MS:
   _abort_stalled_session(_t("السيرفر لم يرد على طلب الغرفة. حاول الاتصال مجددًا.", "Room request timed out. Please reconnect."))
   return
  if ping_waiting and now_ms - ping_sent_ms > PONG_TIMEOUT_MS:
   if not resume_token.is_empty() and not finished:
    _start_reconnect()
   else:
    _abort_stalled_session(_t("الشبكة لا تستجيب. حاول الاتصال مجددًا.", "Network unresponsive. Reconnect to try again."))
   return
  if sync_pending and now_ms - sync_started_ms > SYNC_TIMEOUT_MS:
   if not resume_token.is_empty() and not finished:
    _start_reconnect()
   else:
    _abort_stalled_session(_t("تعذر مزامنة المباراة. ابدأ مباراة جديدة.", "Match sync failed. Start a new match."))
   return
  if action_in_flight and not sync_pending and move_started_ms > 0 and now_ms - move_started_ms > SERVER_REPLY_TIMEOUT_MS:
   sync_pending = true
   sync_started_ms = now_ms
   status.text = _t("جاري مراجعة الحركة مع السيرفر...", "Checking move status with server...")
   _send({"type":"sync"})
  if not connected:
   connected = true
   last_ping_ms = Time.get_ticks_msec()
   ping_waiting = false
   if is_instance_valid(health_label):
    health_label.text = _t("الشبكة: متصل", "Network: connected")
   if not reconnecting:
    connect_started_ms = 0
    status.text = _t("متصل — جاهز للعب", "Connected — ready to play")
   if not reconnecting and not pending_action.is_empty():
    var action := pending_action.duplicate()
    pending_action.clear()
    lobby_request_pending = true
    lobby_request_started_ms = Time.get_ticks_msec()
    matchmaking_pending = str(action.get("type", "")) == "matchmake"
    _update_lobby()
    _send(action)
  if not ping_waiting and not reconnecting and now_ms - last_ping_ms >= PING_INTERVAL_MS:
   ping_sent_ms = now_ms
   last_ping_ms = now_ms
   ping_waiting = true
   _send({"type":"ping", "id":ping_sent_ms})
  while socket.get_available_packet_count() > 0:
   var parsed: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
   if parsed is Dictionary:
    _handle(parsed)
 elif state == WebSocketPeer.STATE_CLOSED and (connected or connect_started_ms > 0):
  if not resume_token.is_empty() and not room_code.is_empty() and not finished and not leaving:
   _start_reconnect()
  else:
   connected = false
   connect_started_ms = 0
   _reset_match_state()
   pending_action.clear()
   socket = WebSocketPeer.new()
   status.text = _t("انقطع الاتصال؛ يمكنك بدء مباراة جديدة.", "Connection lost; start a new match.")

func _abort_stalled_session(message: String) -> void:
 # A delayed server reply may have committed the move already. Never resend it.
 socket.close()
 socket = WebSocketPeer.new()
 connected = false
 connect_started_ms = 0
 pending_action.clear()
 _reset_match_state()
 status.text = message

func _send(message: Dictionary) -> void:
 if audience == "children":
  return
 var action_type := str(message.get("type", ""))
 if action_type in ["ask", "guess"] and action_in_flight:
  return
 if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
  status.text = _local("Connect to the server first")
  return
 var send_error := socket.send_text(JSON.stringify(message))
 if send_error == OK and action_type in ["ask", "guess"]:
  action_in_flight = true
  move_started_ms = Time.get_ticks_msec()
  _refresh_actions()
 elif send_error != OK:
  if action_type in ["create", "join", "matchmake"]:
   lobby_request_pending = false
   matchmaking_pending = false
   lobby_request_started_ms = 0
   _update_lobby()
  elif action_type == "leave":
   _abort_stalled_session(_t("تعذر إرسال المغادرة؛ تم قطع الاتصال.", "Could not send leave; connection closed."))
   return
  status.text = _t("تعذر إرسال الطلب. حاول مجددًا.", "Could not send the request. Try again.")

func _accept_voice_invite() -> void:
 if not voice_opted_in and not voice_request_pending and peer_voice_opted_in:
  _toggle_voice_consent()

func _reset_voice() -> void:
 voice_transport.stop()
 voice_transport_started = false
 voice_microphone.stop()
 voice_level = 0.0
 voice_sent_packets = 0
 voice_received_packets = 0
 voice_capture_frames = 0
 voice_capture_started_ms = 0
 voice_permission_requested = false
 voice_signaling.reset()
 if is_instance_valid(voice_invite_dialog):
  voice_invite_dialog.hide()
 voice_request_pending = false
 voice_request_started_ms = 0
 voice_opted_in = false
 peer_voice_opted_in = false
 _update_voice_ui()

func _update_voice_ui() -> void:
 voice_signaling.set_consent(voice_opted_in, peer_voice_opted_in, not room_code.is_empty() and not finished and not opponent_paused)
 _sync_voice_microphone()
 if not is_instance_valid(voice_button):
  return
 voice_button.disabled = voice_request_pending
 voice_button.text = _t("جاري تأكيد الطلب...", "Confirming request...") if voice_request_pending else _t("إلغاء طلب الصوت", "Cancel voice request") if voice_opted_in else _t("طلب المحادثة الصوتية", "Request voice chat")
 if is_instance_valid(voice_status):
  voice_status.text = (_t("الصوت التجريبي نشط", "Experimental voice chat active") if voice_microphone.is_capturing() else _t("اسمح بالميكروفون من إعدادات التطبيق ثم ارجع للعبة", "Allow microphone in app settings, then return to the game") if OS.get_name() == "Android" and voice_permission_requested and not _voice_permission_granted() else _t("تعذر بدء الميكروفون؛ إعادة المحاولة تلقائيًا", "Microphone failed to start; retrying automatically") if voice_capture_failed else _t("جارٍ تجهيز الميكروفون", "Preparing microphone")) if voice_opted_in and peer_voice_opted_in else _t("في انتظار موافقة الطرف الآخر", "Waiting for the other player") if voice_opted_in else _t("الصوت اختياري ومتوقف افتراضيًا", "Voice is optional and off by default")

func _refresh_voice_diagnostics() -> void:
 var now := Time.get_ticks_msec()
 if now - voice_last_meter_ms < 400 or not is_instance_valid(voice_status):
  return
 voice_last_meter_ms = now
 var bars := clampi(int(voice_level * 24.0), 0, 8)
 var indicator := "▮".repeat(bars) + "▯".repeat(8 - bars)
 if voice_capture_frames == 0 and voice_capture_started_ms > 0 and now - voice_capture_started_ms > 3500:
  voice_status.text = _t("لا تصل عينات من الميكروفون", "No microphone samples detected") + (" | PCM: 0 | TX: 0 | RX: %d" % voice_received_packets)
 else:
  voice_status.text = _t("الميكروفون: ", "Microphone: ") + indicator + (" | PCM: %d | TX: %d | RX: %d" % [voice_capture_frames, voice_sent_packets, voice_received_packets])

func _poll_voice_microphone() -> void:
 # Drain captured PCM to avoid an ever-growing recording buffer.
 # No audio is sent or stored; this is a local input-level diagnostic only.
 var frames: PackedVector2Array = voice_microphone.take_frames(2048)
 if frames.is_empty():
  return
 voice_capture_frames += frames.size()
 var peak := 0.0
 for frame in frames:
  peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
 voice_level = peak
 if voice_transport_started and voice_signaling.ready() and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  for encoded in voice_transport.encode_frames(frames):
   # Audio is best-effort; do not let queued voice block match messages.
   if socket.get_current_outbound_buffered_amount() > 16384:
    break
   if socket.send_text(JSON.stringify({"type": "voice_audio", "pcm": encoded})) == OK:
    voice_sent_packets += 1


func _voice_permission_granted() -> bool:
 if OS.get_name() == "Windows":
  return true
 if OS.get_name() == "Android":
  return "android.permission.RECORD_AUDIO" in OS.get_granted_permissions()
 return false

func _sync_voice_microphone() -> void:
 if not voice_signaling.ready() or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
  voice_microphone.stop()
  voice_transport.stop()
  voice_transport_started = false
  voice_permission_requested = false
  voice_capture_failed = false
  voice_retry_after_ms = 0
  return
 if voice_microphone.is_capturing():
  return
 if not _voice_permission_granted():
  if OS.get_name() == "Android" and not voice_permission_requested:
   voice_permission_requested = true
   OS.request_permission("android.permission.RECORD_AUDIO")
  return
 if voice_microphone.start(self, true, true):
  voice_transport.start(self)
  voice_transport_started = true
  voice_capture_started_ms = Time.get_ticks_msec()
  voice_permission_requested = false
  voice_capture_failed = false
  voice_retry_after_ms = 0
 else:
  voice_capture_failed = true
  voice_retry_after_ms = Time.get_ticks_msec() + 3000
  push_warning("GamingHub voice: microphone capture could not start; retrying in 3s")

func _voice_signal_send(message: Dictionary) -> void:
 if voice_signaling.ready() and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
  _send(message)

func _toggle_voice_consent() -> void:
 if room_code.is_empty() or finished or opponent_paused or voice_request_pending:
  return
 if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
  return
 voice_request_pending = true
 voice_request_started_ms = Time.get_ticks_msec()
 _send({"type": "voice_state", "enabled": not voice_opted_in})
 _update_voice_ui()

func _handle(msg: Dictionary) -> void:
 var kind := str(msg.get("type", ""))
 if leaving and kind not in ["left", "disconnected"]:
  # A create/matchmake request can race with leave; never resurrect its UI.
  return
 if kind in ["turn", "finished", "error", "left", "disconnected"]:
  action_in_flight = false
  move_started_ms = 0
  sync_pending = false
  sync_started_ms = 0
 if kind in ["room", "queue", "started", "error", "left", "disconnected"]:
  lobby_request_pending = false
  lobby_request_started_ms = 0
 match kind:
  "pong":
   if ping_waiting and int(msg.get("id", -1)) == ping_sent_ms:
    latency_ms = maxi(0, Time.get_ticks_msec() - ping_sent_ms)
    ping_waiting = false
    if is_instance_valid(health_label):
     health_label.text = (_t("الشبكة: بطيئة • %d مللي ثانية", "Network: slow • %d ms") if latency_ms > 600 else _t("الشبكة: مستقرة • %d مللي ثانية", "Network: stable • %d ms")) % latency_ms
  "voice_state":
   var incoming_enabled := bool(msg.get("enabled", false))
   var show_invite := incoming_enabled and not peer_voice_opted_in and not voice_opted_in and not voice_request_pending and not finished
   peer_voice_opted_in = incoming_enabled
   _update_voice_ui()
   if show_invite and is_instance_valid(voice_invite_dialog):
    voice_invite_dialog.popup_centered()
   elif not incoming_enabled and is_instance_valid(voice_invite_dialog):
    voice_invite_dialog.hide()
  "voice_offer", "voice_answer", "voice_ice":
   voice_signaling.handle_server_message(msg)
  "voice_audio":
   if voice_signaling.ready() and voice_transport_started:
    if voice_transport.receive_packet(str(msg.get("pcm", ""))):
     voice_received_packets += 1
  "voice_state_ack":
   voice_request_pending = false
   voice_request_started_ms = 0
   voice_opted_in = bool(msg.get("enabled", false))
   peer_voice_opted_in = bool(msg.get("peer_enabled", false))
   _update_voice_ui()
  "paused":
   _reset_voice()
   opponent_paused = true
   var remaining_seconds := maxi(0, int(msg.get("seconds", 90)))
   status.text = (_t("انقطع اتصال المنافس؛ المباراة محفوظة مؤقتًا لمدة %d ثانية في انتظار عودته.", "Opponent disconnected; match reserved for %d seconds while they reconnect.") % remaining_seconds)
   _refresh_actions()
  "peer_resumed":
   _reset_voice()
   opponent_paused = false
   my_turn = int(msg.get("turn", -1)) == player_index
   status.text = _t("المنافس رجع؛ المباراة مستمرة.", "Opponent reconnected; match resumed.")
   _refresh_actions()
  "resumed", "synced":
   # The authoritative snapshot replaces local state; do NOT replay a timed-out move.
   var replay: Array = msg.get("history", [])
   var started_message: Dictionary = msg.duplicate()
   started_message["type"] = "started"
   # A sync snapshot deliberately has no credential: preserve our existing token.
   if kind == "synced":
    started_message["resume_token"] = resume_token
   _handle(started_message)
   for event in replay:
    if event is Dictionary and str(event.get("type", "")) in ["question", "guess", "finished"]:
     _handle(event)
   opponent_paused = bool(msg.get("paused", false))
   finished = bool(msg.get("finished", false))
   reconnecting = false
   reconnect_pending = false
   sync_pending = false
   sync_started_ms = 0
   action_in_flight = false
   move_started_ms = 0
   reconnect_deadline_ms = 0
   reconnect_next_ms = 0
   if finished:
    status.text = _t("تم استرجاع نتيجة المباراة", "Match result restored")
   else:
    status.text = _t("تمت مزامنة المباراة مع السيرفر", "Match synchronized with server") if kind == "synced" else _t("تم استكمال المباراة بنجاح", "Match restored successfully")
   _refresh_actions()
  "left":
   _reset_voice()
   _reset_match_state()
   status.text = _t("خرجت من الغرفة", "Left the room")
  "queue":
   pending_action.clear()
   matchmaking_pending = str(msg.get("status", "")) == "waiting"
   _update_lobby()
   status.text = _t("جاري البحث عن منافس...", "Finding an opponent...") if matchmaking_pending else _t("تم إلغاء البحث", "Search cancelled")
  "room":
   pending_action.clear()
   matchmaking_pending = false
   my_turn = false
   finished = false
   room_code = str(msg.get("code", ""))
   _update_lobby()
   status.text = _local("ROOM CODE: ") + room_code + " • " + _local(str(msg.get("status", "")))
  "started":
   _reset_voice()
   pending_action.clear()
   matchmaking_pending = false
   _clear_match_view()
   question_page = 0
   candidate_page = 0
   asked_questions.clear()
   player_index = int(msg.get("player_index", -1))
   resume_token = str(msg.get("resume_token", ""))
   # The old server can start a room but cannot resume it. Make this visible
   # instead of silently returning the player to the join-code form.
   if resume_token.is_empty():
    status.text = _t("السيرفر يحتاج تحديث لدعم استكمال المباريات. يمكنك اللعب لكن استعادة الاتصال غير متاحة.", "Server update required for match recovery. You can play, but reconnection is unavailable.")
   opponent_paused = false
   opponent_card = str(msg.get("opponent_card", {}).get("name", ""))
   possible_cards.clear()
   for item in catalog.get("cards", []):
    if item is Dictionary and str(item.get("name", "")) != opponent_card:
     possible_cards.append(item)
   localized_questions = {"ar": msg.get("questions_ar", []), "en": msg.get("questions", []), "tr": msg.get("questions_tr", [])}
   questions = localized_questions.get(language, [])
   if questions.is_empty():
    questions = msg.get("questions", [])
   my_turn = bool(msg.get("your_turn", false))
   finished = false
   match_label.text = _t("👀 بطاقة منافسك: ", "👀 OPPONENT CARD: ") + display_card(opponent_card) + _t(" | 🔒 بطاقتك: ؟؟؟", " | 🔒 YOUR CARD: ???")
   deduction_status = Label.new()
   deduction_status.add_theme_font_size_override("font_size", 18)
   deduction_status.add_theme_color_override("font_color", Color("a7f3d0"))
   match_view.add_child(deduction_status)
   voice_invite_dialog = ConfirmationDialog.new()
   voice_invite_dialog.title = _t("طلب محادثة صوتية", "Voice chat request")
   voice_invite_dialog.dialog_text = _t("الطرف الآخر يطلب محادثة صوتية. هل توافق؟", "The other player requests voice chat. Accept?")
   voice_invite_dialog.ok_button_text = _t("موافقة", "Accept")
   voice_invite_dialog.cancel_button_text = _t("رفض", "Decline")
   voice_invite_dialog.confirmed.connect(_accept_voice_invite)
   add_child(voice_invite_dialog)
   voice_button = Button.new()
   voice_button.custom_minimum_size.y = 50
   voice_button.pressed.connect(_toggle_voice_consent)
   match_view.add_child(voice_button)
   voice_status = Label.new()
   voice_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   match_view.add_child(voice_status)
   _update_voice_ui()
   _update_deduction_status()
   var art_frame := PanelContainer.new()
   art_frame.custom_minimum_size.y = 255
   art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
   var art_style_box := StyleBoxFlat.new()
   art_style_box.bg_color = PANEL
   art_style_box.set_corner_radius_all(18)
   art_style_box.set_content_margin_all(10)
   art_frame.add_theme_stylebox_override("panel", art_style_box)
   card_art = TextureRect.new()
   card_art.texture = online_card_texture(opponent_card)
   card_art.custom_minimum_size.y = 235
   card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
   art_frame.add_child(card_art)
   match_view.add_child(art_frame)
   match_view.move_child(art_frame, 1)
   if card_art.texture == null:
    _match_note(_t("الصورة غير متاحة على هذا الجهاز؛ اسم بطاقة المنافس ظاهر بالأعلى.", "Image unavailable on this device; opponent card name appears above."), 14)
   if art_style == "realistic" and ResourceLoader.exists("res://assets/generated/" + opponent_card.to_lower() + ".webp") and not ResourceLoader.exists("res://assets/photos/" + opponent_card.to_lower() + ".jpg"):
    _match_note(_t("صورة واقعية مولدة بالذكاء الاصطناعي", "AI-generated realistic image"), 14)
   _refresh_actions()
  "turn":
   my_turn = int(msg.get("player", -1)) == _my_index()
   status.text = (_t("دورك", "Your turn") if my_turn else _t("دور المنافس", "Opponent's turn"))
   _refresh_actions()
  "question":
   # Only our own answers narrow our secret card. The opponent's questions
   # concern THEIR secret and must never affect our deduction board.
   if int(msg.get("player", -1)) == player_index:
    _apply_answer(str(msg.get("text", "")), bool(msg.get("answer", false)))
   _match_note(_t("سؤال: ", "Question: ") + str(msg.get("text_" + language, msg.get("text", ""))) + " → " + (_t("نعم", "YES") if msg.get("answer", false) else _t("لا", "NO")), 16)
   _update_deduction_status()
  "guess":
   if int(msg.get("player", -1)) == player_index and not bool(msg.get("correct", false)):
    _remove_wrong_guess(str(msg.get("guess", "")))
   _match_note(_t("تخمين: ", "Guess: ") + str(msg.get("guess", "")) + (" ✓" if msg.get("correct", false) else " ✗"), 16)
   _update_deduction_status()
  "finished":
   _reset_voice()
   finished = true
   my_turn = false
   var names: Array[String] = []
   for name in msg.get("cards", []):
    names.append(display_card(str(name)))
   var winner := int(msg.get("winner", -1))
   var result_text := _t("تعادل!", "Draw!") if winner == -1 else (_t("مبروك! أنت الفائز", "You won!") if winner == player_index else _t("المنافس فاز", "Opponent won"))
   _match_note(result_text + " • " + _t("الصور: ", "Cards: ") + " / ".join(names), 20)
   status.text = _t("المباراة انتهت. غادر الغرفة لبدء مباراة جديدة.", "Match finished. Leave the room to start a new game.")
   _update_lobby()
   _refresh_actions()
  "disconnected":
   _reset_voice()
   _reset_match_state()
   _match_note(_t("انتهت جلسة المنافس أو مهلة عودته؛ يمكنك بدء مباراة جديدة.", "Opponent session or reconnection window ended; you can start a new match."), 18)
   _refresh_actions()
  "error":
   if voice_request_pending:
    voice_request_pending = false
    voice_request_started_ms = 0
    _update_voice_ui()
   if reconnect_pending:
    if str(msg.get("message", "")) == "Original player still connected":
     # Server may not have detected the dead TCP peer yet; wait for its ping timeout.
     socket.close()
     socket = WebSocketPeer.new()
     connected = false
     reconnect_pending = false
     connect_started_ms = 0
     reconnect_next_ms = Time.get_ticks_msec() + 2500
     return
    var resume_reason := str(msg.get("message", "Unknown server error"))
    push_warning("GamingHub resume rejected: " + resume_reason)
    _abort_stalled_session(_t("فشل استكمال المباراة: ", "Match resume failed: ") + resume_reason)
    return
   action_in_flight = false
   _refresh_actions()
   matchmaking_pending = false
   _update_lobby()
   status.text = _local(str(msg.get("message", "Server error")))

var deduction_status: Label
func _update_deduction_status() -> void:
 if not is_instance_valid(deduction_status):
  return
 deduction_status.text = _t("🧩 الاحتمالات المتبقية: %d", "🧩 Remaining possibilities: %d") % possible_cards.size()

func _apply_answer(question_text: String, answer: bool) -> void:
 var question_index := -1
 var question: Dictionary = {}
 var all_questions: Array = catalog.get("questions", [])
 for i in range(all_questions.size()):
  var candidate: Dictionary = all_questions[i]
  if str(candidate.get("text", "")) == question_text:
   question_index = i
   question = candidate
   break
 if question_index < 0:
  return
 if question_index not in asked_questions:
  asked_questions.append(question_index)
 var key: String = str(question.get("key", ""))
 var target: Variant = question.get("value")
 var remaining: Array = []
 for card in possible_cards:
  if card is Dictionary and card.has(key) and (card[key] == target) == answer:
   remaining.append(card)
 # A corrupt/mismatched catalog should never expose the hidden card or
 # silently replace the board with an impossible list.
 possible_cards = remaining
 candidate_page = 0
 question_page = 0

func _remove_wrong_guess(value: String) -> void:
 var normalized: String = _normalize_guess(value)
 var remaining: Array = []
 for card in possible_cards:
  var aliases: Array = [card.get("name", ""), card.get("ar", ""), card.get("en", "")]
  aliases.append_array(card.get("aliases", []))
  var matches := false
  for alias in aliases:
   if _normalize_guess(str(alias)) == normalized:
    matches = true
    break
  if not matches:
   remaining.append(card)
 possible_cards = remaining
 candidate_page = 0

func _normalize_guess(value: String) -> String:
 var result := value.strip_edges().to_lower()
 for mark in ["َ", "ً", "ُ", "ٌ", "ِ", "ٍ", "ْ", "ّ", "ـ"]:
  result = result.replace(mark, "")
 for source in ["أ", "إ", "آ"]:
  result = result.replace(source, "ا")
 result = result.replace("ى", "ي")
 for separator in [" ", "_", "-", "."]:
  result = result.replace(separator, "")
 if result.begins_with("ال"):
  result = result.substr(2)
 return result

func _guess_card(card_name: String) -> void:
 _send({"type":"guess", "guess":card_name})

func _previous_candidates() -> void:
 candidate_page = maxi(0, candidate_page - 1)
 _refresh_actions()

func _next_candidates() -> void:
 candidate_page += 1
 _refresh_actions()

func _match_note(value: String, size: int = 16) -> void:
 var l := Label.new()
 l.text = value
 l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size", size)
 l.add_theme_color_override("font_color", Color.WHITE)
 match_view.add_child(l)

func _copy_invite() -> void:
 if room_code.is_empty():
  return
 DisplayServer.clipboard_set(_t("انضم لغرفتي في Gaming Hub! كود الغرفة: ", "Join my Gaming Hub room! Room code: ") + room_code + "\n" + _t("افتح اللعبة > Friends > Join room وأدخل الكود.", "Open the game > Friends > Join room and enter the code."))
 status.text = _t("تم نسخ الدعوة — ابعتها لصاحبك", "Invitation copied — send it to a friend")

func _toggle_language() -> void:
 language = ["ar", "en"][(["ar", "en"].find(language) + 1) % 2]
 refresh_localized_controls(output)
 language_button.text = "العربية / English"
 if is_instance_valid(create_button):
  create_button.text = _t("إنشاء غرفة لصديق", "Create a friend room")
  join_button.text = _t("انضمام بكود", "Join with code")
  match_button.text = _t("منافس عشوائي", "Find an opponent")
 share_button.text = _t("نسخ دعوة الغرفة", "Copy room invitation")
 if localized_questions.has(language):
  questions = localized_questions[language]
  _refresh_actions()
 status.text = language
 var path: String = "user://progress_v10_" + audience + ".json"
 var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
 if saved is Dictionary:
  saved["language"] = language
  var file := FileAccess.open(path, FileAccess.WRITE)
  if file != null:
   file.store_string(JSON.stringify(saved))
   file.close()

func _local(value: String) -> String:
 if language == "ar":
  return str(ui_ar.get(value, value))
 return value

func refresh_localized_controls(node: Node) -> void:
 if node.has_meta("ui_source") and (node is Label or node is Button):
  node.text = _local(str(node.get_meta("ui_source")))
 if node is LineEdit and node.has_meta("ui_hint"):
  node.placeholder_text = _local(str(node.get_meta("ui_hint")))
 for child in node.get_children():
  refresh_localized_controls(child)

func display_card(name: String) -> String:
 for card in catalog.get("cards", []):
  if str(card["name"]) == name:
   return str(card.get(language, name))
 return name


var player_index := -1
func online_card_texture(card_name: String) -> Texture2D:
 var base: String = card_name.to_lower()
 var illustrated: String = "res://assets/cards/" + base + ".png"
 if art_style == "illustration" and ResourceLoader.exists(illustrated):
  return load(illustrated) as Texture2D
 for path in ["res://assets/photos/" + base + ".jpg", "res://assets/generated/" + base + ".webp", illustrated]:
  if ResourceLoader.exists(path):
   return load(path) as Texture2D
 return null

func _my_index() -> int:
 return player_index

# Rank questions by how evenly they divide the remaining public possibilities.
# This is a hint, not a peek at the server-side hidden card.
func _available_question_indices() -> Array[int]:
 var remaining: Array[int] = []
 for i in range(questions.size()):
  if i in asked_questions:
   continue
  remaining.append(i)
 return remaining

func _recommended_question_index() -> int:
 if possible_cards.size() <= 1:
  return -1
 var best_index: int = -1
 var best_split: int = -1
 var all_questions: Array = catalog.get("questions", [])
 for i in _available_question_indices():
  if i >= all_questions.size():
   continue
  var question: Dictionary = all_questions[i]
  var key: String = str(question.get("key", ""))
  var yes_count: int = 0
  for card in possible_cards:
   if card is Dictionary and card.get(key) == question.get("value"):
    yes_count += 1
  var split_score: int = mini(yes_count, possible_cards.size() - yes_count)
  if split_score > best_split and split_score > 0:
   best_split = split_score
   best_index = i
 return best_index

func _refresh_actions() -> void:
 for child in action_area.get_children():
  child.queue_free()
 if finished or not my_turn or action_in_flight or reconnecting or opponent_paused:
  if action_in_flight:
   var waiting_label := Label.new()
   waiting_label.text = _t("جاري إرسال الحركة...", "Sending move...")
   action_area.add_child(waiting_label)
  return
 # Candidate names are public deck options, never the player's hidden answer.
 # Show the most useful question FIRST so it is reachable without long scrolling.
 var count_label := Label.new()
 count_label.text = _t("الصور المحتملة: %d", "Possible cards: %d") % possible_cards.size()
 count_label.add_theme_font_size_override("font_size", 19)
 count_label.add_theme_color_override("font_color", Color("a7f3d0"))
 action_area.add_child(count_label)
 var deduction_bar := ProgressBar.new()
 deduction_bar.custom_minimum_size.y = 14
 deduction_bar.max_value = maxi(1, catalog.get("cards", []).size() - 1)
 deduction_bar.value = clampi(int(deduction_bar.max_value) - possible_cards.size(), 0, int(deduction_bar.max_value))
 deduction_bar.show_percentage = false
 deduction_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
 action_area.add_child(deduction_bar)
 var suggestion: int = _recommended_question_index()
 if suggestion >= 0:
  var recommended: int = suggestion
  _button(_t("💡 سؤال ذكي: ", "💡 SMART QUESTION: ") + str(questions[recommended]), func(): _send({"type":"ask", "question":recommended}), action_area)
 elif possible_cards.size() == 1:
  var ready_note := Label.new()
  ready_note.text = _t("بقيت بطاقة واحدة! خمنها الآن.", "One card remains! Try guessing it.")
  ready_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  ready_note.add_theme_color_override("font_color", Color("a7f3d0"))
  action_area.add_child(ready_note)
 if not possible_cards.is_empty():
  var page_count_cards := ceili(float(possible_cards.size()) / float(CANDIDATES_PER_PAGE))
  candidate_page = clampi(candidate_page, 0, page_count_cards - 1)
  for index in range(candidate_page * CANDIDATES_PER_PAGE, mini((candidate_page + 1) * CANDIDATES_PER_PAGE, possible_cards.size())):
   var card: Dictionary = possible_cards[index]
   var card_name: String = str(card.get("name", ""))
   _button(_t("خمن: ", "Guess: ") + display_card(card_name), func(): _guess_card(card_name), action_area)
  if page_count_cards > 1:
   var paging := HBoxContainer.new()
   action_area.add_child(paging)
   var back := Button.new()
   back.text = _t("بطاقات سابقة", "Previous cards")
   back.disabled = candidate_page == 0
   back.custom_minimum_size.y = 48
   back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
   back.pressed.connect(_previous_candidates)
   _style_button(back)
   paging.add_child(back)
   var forward := Button.new()
   forward.text = _t("بطاقات أخرى", "More cards")
   forward.disabled = candidate_page >= page_count_cards - 1
   forward.custom_minimum_size.y = 48
   forward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
   forward.pressed.connect(_next_candidates)
   _style_button(forward)
   paging.add_child(forward)
 # Manual guess remains available for aliases and accessibility.
 guess_input = LineEdit.new()
 guess_input.placeholder_text = _t("اكتب اسم صورتك السرية", "Guess your secret picture")
 guess_input.custom_minimum_size.y = 52
 guess_input.max_length = 80
 action_area.add_child(guess_input)
 _button(_t("تأكيد التخمين", "Submit guess"), _submit_guess, action_area)
 if questions.is_empty():
  return
 var available: Array[int] = _available_question_indices()
 if available.is_empty():
  return
 var page_count := int(ceil(float(available.size()) / float(QUESTIONS_PER_PAGE)))
 question_page = clampi(question_page, 0, page_count - 1)
 var page_label := Label.new()
 page_label.text = _t("أسئلة نعم / لا", "Yes / No questions") + " (%d/%d)" % [question_page + 1, page_count]
 page_label.add_theme_font_size_override("font_size", 18)
 action_area.add_child(page_label)
 var start_index := question_page * QUESTIONS_PER_PAGE
 for i in available.slice(start_index, mini(start_index + QUESTIONS_PER_PAGE, available.size())):
  var question_index: int = i
  _button(str(questions[question_index]), func(): _send({"type":"ask","question":question_index}), action_area)
 if page_count > 1:
  var nav := HBoxContainer.new()
  nav.add_theme_constant_override("separation", 8)
  action_area.add_child(nav)
  var previous := Button.new()
  previous.text = _t("السابق", "Previous")
  previous.custom_minimum_size.y = 52
  previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  previous.disabled = question_page == 0
  previous.pressed.connect(_prev_questions)
  _style_button(previous)
  nav.add_child(previous)
  var next := Button.new()
  next.text = _t("التالي", "Next")
  next.custom_minimum_size.y = 52
  next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  next.disabled = question_page >= page_count - 1
  next.pressed.connect(_next_questions)
  _style_button(next)
  nav.add_child(next)

func _submit_guess() -> void:
 if not is_instance_valid(guess_input):
  return
 var value := guess_input.text.strip_edges()
 if not value.is_empty():
  _send({"type":"guess", "guess":value})

func _prev_questions() -> void:
 question_page = maxi(0, question_page - 1)
 _refresh_actions()

func _next_questions() -> void:
 question_page += 1
 _refresh_actions()
