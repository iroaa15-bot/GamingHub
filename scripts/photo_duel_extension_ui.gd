extends Control
## Embedded local/staging screen; no standalone app and no voice-module changes.
const Client = preload("res://scripts/photo_duel_extension_client.gd")
const VisualSkin = preload("res://scripts/visual_skin.gd")
const FACTS := {"living":["هل هو كائن حي؟","Is it alive?"],"animal":["هل هو حيوان؟","Is it an animal?"],"celebrity":["هل هو شخص مشهور؟","Is it a celebrity?"],"edible":["هل يمكن أكله؟","Is it edible?"],"household":["هل يُستخدم في المنزل؟","Is it used at home?"],"natural":["هل يوجد في الطبيعة؟","Is it found in nature?"],"place":["هل هو مكان؟","Is it a place?"],"large":["هل حجمه كبير؟","Is it large?"]}
var client: Node
var language := "ar"
var column: VBoxContainer
var status: Label
var heading: Label
var clock: Label
var question_label: Label
var chat_log: Label
var code_field: LineEdit
var chat_field: LineEdit
var question_field: LineEdit
var guess_field: LineEdit
var players_field: OptionButton
var timer_field: OptionButton
var target_field: SpinBox
var create_button: Button
var join_button: Button
var resume_button: Button
var chat_button: Button
var question_button: Button
var guess_button: Button
var yes_button: Button
var no_button: Button
var correct_button: Button
var wrong_button: Button
var pass_button: Button
var presets: Dictionary = {}
var images: Array[TextureRect] = []
var captions: Array[Label] = []
var catalog: Dictionary = {}
var received_at := 0
var local_remaining := -1
var endpoint_field: LineEdit
var terms: CheckBox
var voice_adapter: Node
var voice_button: Button
var voice_status: Label
var target_player: OptionButton
var report_reason: LineEdit
var report_button: Button
var block_button: Button
var _match_controls: VBoxContainer
var _lobby_controls: VBoxContainer
var _match_header: HBoxContainer
var _clock_bar: ProgressBar
var _turn_ms := 30000
var _main_column: VBoxContainer
var _settings_body: VBoxContainer
var _settings_toggle: Button
var _reply_row: HBoxContainer
var _was_active := false
var _seat_labels: Array[Label] = []
var _seat_panels: Array[PanelContainer] = []
var _seat_avatars: Array[TextureRect] = []
var _seats: GridContainer
var _scores: Label
var _menu_touch_guard: Node


func tr_pair(ar: String, en: String) -> String:
 return ar if language == "ar" else en

func label(value: String, size: int = 18) -> Label:
 var control := Label.new()
 control.text = value
 control.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if language == "ar" else HORIZONTAL_ALIGNMENT_LEFT
 control.mouse_filter = Control.MOUSE_FILTER_IGNORE
 control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 control.add_theme_font_size_override("font_size", size)
 column.add_child(control)
 return control

func field(hint: String) -> LineEdit:
 var control := LineEdit.new()
 control.placeholder_text = hint
 control.custom_minimum_size.y = 52
 column.add_child(control)
 return control

func button(value: String, action: Callable) -> Button:
 var control := Button.new()
 control.text = value
 control.custom_minimum_size.y = 56
 VisualSkin.decorate_button(control,"gold")
 control.pressed.connect(_invoke.bind(weakref(control),action),CONNECT_DEFERRED)
 column.add_child(control)
 return control

func _section(title: String, expanded: bool = false) -> VBoxContainer:
 var body := VBoxContainer.new()
 body.add_theme_constant_override("separation",8)
 body.visible = expanded
 var toggle := button(title,func(): body.visible = not body.visible)
 toggle.text=title.trim_prefix("⚙ ").trim_prefix("☷ ").trim_prefix("✉ ")
 VisualSkin.decorate_button(toggle,"secondary")
 toggle.icon = VisualSkin.menu_icon("chat" if title.contains("✉") else ("list" if title.contains("☷") else "settings"))
 toggle.expand_icon = true
 toggle.add_theme_constant_override("icon_max_width",22)
 column.add_child(body)
 return body

func _invoke(ref: WeakRef, action: Callable) -> void:
 if is_instance_valid(_menu_touch_guard): _menu_touch_guard.dispatch(_execute_menu_action.bind(ref,action))
 else: _execute_menu_action(ref,action)

func _execute_menu_action(ref: WeakRef, action: Callable) -> void:
 var control: Variant = ref.get_ref()
 if is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(control) and control.is_inside_tree() and not control.is_queued_for_deletion() and not control.disabled:
  action.call()

func _ready() -> void:
 get_tree().quit_on_go_back = false
 var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://progress_v10_all.json")) if FileAccess.file_exists("user://progress_v10_all.json") else null
 if saved is Dictionary: language = str(saved.get("language","ar"))
 layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "ar" else Control.LAYOUT_DIRECTION_LTR
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guess_picture_302/catalog.json"))
 for item in data.items:
  if item.group == "original_200": catalog[str(item.image)] = item
 var bg := VisualSkin.new()
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(bg)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.scroll_deadzone = 14
 scroll.follow_focus = true
 _menu_touch_guard = load("res://scripts/menu_touch_guard.gd").new()
 _menu_touch_guard.scroll_area = scroll
 scroll.add_child(_menu_touch_guard)
 add_child(scroll)
 var margin := MarginContainer.new()
 for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
 margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(margin)
 column = VBoxContainer.new()
 column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",8)
 margin.add_child(column)
 VisualSkin.compact_header(column,tr_pair("غرف الأصدقاء • خمن صورتك","Friend rooms • Guess Your Picture"))
 status = label(tr_pair("اختر إعدادات الغرفة واتصل بالخدمة عند تفعيلها.","Choose room settings and connect when the service is enabled."))
 heading = label("",22)
 _scores = label("",16)
 clock = label("")
 clock.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 _clock_bar=ProgressBar.new()
 _clock_bar.show_percentage=false
 _clock_bar.custom_minimum_size.y=7
 _clock_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var track := StyleBoxFlat.new()
 track.bg_color=Color("102b4a")
 track.set_corner_radius_all(4)
 var fill := track.duplicate() as StyleBoxFlat
 fill.bg_color=Color("00cf81")
 _clock_bar.add_theme_stylebox_override("background",track)
 _clock_bar.add_theme_stylebox_override("fill",fill)
 column.add_child(_clock_bar)
 _seats = GridContainer.new()
 _seats.columns = 3
 _seats.add_theme_constant_override("h_separation",8)
 _seats.add_theme_constant_override("v_separation",8)
 column.add_child(_seats)
 for seat in range(6):
  var panel := PanelContainer.new()
  panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  panel.custom_minimum_size.y = 76
  panel.add_theme_stylebox_override("panel",VisualSkin.card(Color("082033"),12))
  _seats.add_child(panel)
  _seat_panels.append(panel)
  var seat_content := VBoxContainer.new()
  seat_content.add_theme_constant_override("separation",4)
  panel.add_child(seat_content)
  var avatar := TextureRect.new()
  avatar.texture=VisualSkin.menu_icon("player")
  avatar.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  avatar.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  avatar.custom_minimum_size=Vector2(36,36)
  avatar.mouse_filter=Control.MOUSE_FILTER_IGNORE
  seat_content.add_child(avatar)
  _seat_avatars.append(avatar)
  var name_label := Label.new()
  name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  name_label.add_theme_font_size_override("font_size",14)
  seat_content.add_child(name_label)
  _seat_labels.append(name_label)
 var main_column := column
 _main_column=main_column
 _match_header=HBoxContainer.new()
 _match_header.add_theme_constant_override("separation",8)
 main_column.add_child(_match_header)
 var settings_index := column.get_child_count()
 column = _section(tr_pair("⚙ إعدادات الغرفة والاتصال","⚙ Room & connection settings"))
 _settings_body=column
 _settings_toggle=main_column.get_child(settings_index)
 endpoint_field = field(tr_pair("عنوان الخدمة المعتمد؛ لا يزال النشر معلقًا","Approved service address; deployment pending"))
 endpoint_field.text = Client.endpoint_from_args()
 endpoint_field.layout_direction = Control.LAYOUT_DIRECTION_LTR
 label(tr_pair("الدردشة والصوت اختياريان. يمنع الإساءة والتهديد ونشر المعلومات الشخصية والمحتوى غير الملائم. يمكنك الإبلاغ وحظر لاعب. لا يبدأ الميكروفون دون موافقتك.","Chat and voice are optional. Abuse, threats, personal information and inappropriate content are prohibited. You can report or block players. The microphone requires your consent."),15)
 terms = CheckBox.new()
 terms.custom_minimum_size.y = 54
 terms.text = tr_pair("أوافق على قواعد الغرف واستخدام الدردشة","I accept the room and chat rules")
 column.add_child(terms)
 label(tr_pair("عدد اللاعبين","Number of players"))
 players_field = OptionButton.new()
 players_field.custom_minimum_size.y = 54
 for count in range(2,7): players_field.add_item(str(count),count)
 column.add_child(players_field)
 label(tr_pair("مدة الدور بالثواني","Turn time in seconds"))
 timer_field = OptionButton.new()
 timer_field.custom_minimum_size.y = 54
 for seconds in [0,10,20,30,60]: timer_field.add_item(tr_pair("بدون مؤقت","No timer") if seconds == 0 else str(seconds),seconds)
 timer_field.select(3)
 column.add_child(timer_field)
 label(tr_pair("نقاط الفوز","Winning score"))
 target_field = SpinBox.new()
 target_field.min_value = 1
 target_field.max_value = 50
 target_field.value = 10
 column.add_child(target_field)
 column = main_column
 _lobby_controls = VBoxContainer.new()
 _lobby_controls.add_theme_constant_override("separation",8)
 main_column.add_child(_lobby_controls)
 column = _lobby_controls
 create_button = button(tr_pair("إنشاء غرفة","Create room"),func(): client.create_room(players_field.get_selected_id(),timer_field.get_selected_id(),int(target_field.value)))
 code_field = field(tr_pair("كود الغرفة","Room code"))
 code_field.layout_direction = Control.LAYOUT_DIRECTION_LTR
 join_button = button(tr_pair("انضمام بكود","Join by code"),func(): client.join_room(code_field.text))
 resume_button = button(tr_pair("استعادة الاتصال","Reconnect session"),func(): client.resume_session())
 button(tr_pair("الاتصال بخدمة الغرف","Connect to room service"),_connect_service)
 _match_controls = VBoxContainer.new()
 _match_controls.add_theme_constant_override("separation",8)
 main_column.add_child(_match_controls)
 column = _match_controls
 for i in range(6):
  captions.append(label(""))
  var picture := TextureRect.new()
  picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
  picture.custom_minimum_size.y = 240
  picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  column.add_child(picture)
  images.append(picture)
 question_label = label("")
 question_field = field(tr_pair("سؤال نصي للمجيب المحدد","Text question for the designated opponent"))
 question_button = button(tr_pair("إرسال السؤال","Send question"),func(): client.send_action("duel_question",{"text":question_field.text}))
 var match_column := column
 column = _section(tr_pair("☷ الأسئلة الجاهزة","☷ Preset questions"))
 for key in FACTS:
  var fact: String = key
  presets[fact] = button(str(FACTS[fact][0 if language == "ar" else 1]),func(): client.send_action("duel_preset",{"question_id":fact}))
 column = match_column
 _reply_row = HBoxContainer.new()
 var reply_row := _reply_row
 reply_row.add_theme_constant_override("separation",8)
 column.add_child(reply_row)
 yes_button = button(tr_pair("نعم","Yes"),func(): client.send_action("duel_reply",{"answer":true}))
 no_button = button(tr_pair("لا","No"),func(): client.send_action("duel_reply",{"answer":false}))
 for reply in [yes_button,no_button]:
  column.remove_child(reply)
  reply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  reply_row.add_child(reply)
 column.move_child(reply_row,column.get_children().find(question_label)+1)
 VisualSkin.decorate_button(yes_button,"teal")
 guess_field = field(tr_pair("تخمينك؛ يؤكده المنافس المحدد","Your guess; confirmed by designated opponent"))
 guess_button = button(tr_pair("طلب تأكيد التخمين","Request guess confirmation"),func(): client.send_action("duel_guess",{"guess":guess_field.text}))
 guess_button.reparent(_reply_row)
 guess_button.text=tr_pair("تأكيد التخمين","Confirm guess")
 guess_button.tooltip_text=tr_pair("أدخل تخمينك ثم اطلب تأكيد المنافس","Enter your guess, then request opponent confirmation")
 for primary in [yes_button,no_button,guess_button]:
  primary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  primary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  primary.add_theme_font_size_override("font_size",14)
 correct_button = button(tr_pair("التخمين صحيح","Guess is correct"),func(): client.send_action("duel_confirm",{"correct":true}))
 wrong_button = button(tr_pair("التخمين خطأ","Guess is incorrect"),func(): client.send_action("duel_confirm",{"correct":false}))
 pass_button = button(tr_pair("تمرير الدور","Pass turn"),func(): client.send_action("duel_pass"))
 column = _section(tr_pair("✉ الدردشة النصية","✉ Text chat"))
 chat_log = label("")
 chat_field = field(tr_pair("دردشة نصية لجميع لاعبي الغرفة","Text chat for everyone in the room"))
 chat_field.max_length = 280
 chat_button = button(tr_pair("إرسال الدردشة","Send chat"),_chat)
 column = match_column
 voice_button = button(tr_pair("تفعيل الميكروفون","Enable microphone"),func(): voice_adapter.enable(not voice_adapter.requested))
 voice_status = label("")
 column = _section(tr_pair("⚙ الإبلاغ والحظر","⚙ Report & block"))
 target_player = OptionButton.new()
 target_player.custom_minimum_size.y = 54
 for index in range(6): target_player.add_item(tr_pair("اللاعب ","Player ")+str(index+1),index)
 column.add_child(target_player)
 report_reason = field(tr_pair("سبب الإبلاغ","Report reason"))
 report_button = button(tr_pair("الإبلاغ عن اللاعب","Report player"),func(): client.send_action("duel_report",{"target":target_player.get_selected_id(),"reason":report_reason.text}))
 block_button = button(tr_pair("حظر اللاعب ومغادرة الغرفة","Block player and leave room"),func(): client.send_action("duel_block",{"target":target_player.get_selected_id()}))
 column = main_column
 button(tr_pair("مغادرة الغرفة","Leave room"),func(): client.send_action("duel_leave"))
 var back_button := button(tr_pair("العودة إلى Gaming Hub","Back to Gaming Hub"),_home)
 back_button.icon = VisualSkin.menu_icon("back")
 back_button.expand_icon = true
 back_button.add_theme_constant_override("icon_max_width",22)
 client = Client.new()
 add_child(client)
 client.state_changed.connect(_state)
 client.event_received.connect(func(message: Dictionary):
  if message.get("type") == "duel_error": status.text = str(message.get("message",""))
  elif message.get("type") == "duel_reported": status.text = tr_pair("حُفظ البلاغ: ","Report saved: ")+str(message.get("report_id",""))
  elif message.get("type") == "duel_blocked": status.text = tr_pair("تم حظر اللاعب","Player blocked")
 )
 client.connection_changed.connect(func(_ready: bool): _state(client.state))
 voice_adapter = load("res://scripts/photo_duel_voice_adapter.gd").new()
 add_child(voice_adapter)
 voice_adapter.attach(client)
 voice_adapter.changed.connect(_voice_changed)
 voice_adapter.unavailable.connect(func(reason: String): voice_status.text = reason)
 if not Client.endpoint_from_args().is_empty() and Client.endpoint_from_args().begins_with("ws://"):
  client.connect_endpoint(Client.endpoint_from_args())
 _state({})
 _voice_changed()
 VisualSkin.compact_menu(main_column)
 VisualSkin.decorate_button(yes_button,"teal")
 VisualSkin.decorate_button(no_button,"danger")
 VisualSkin.decorate_button(guess_button,"amber")
 for primary in [yes_button,no_button,guess_button]:
  primary.add_theme_font_size_override("font_size",14)
 VisualSkin.enable_menu_swipe(column)

func _chat() -> void:
 if client.send_action("duel_chat",{"text":chat_field.text}) == OK: chat_field.clear()

func _state(value: Dictionary) -> void:
 var ready: bool = not client.capabilities.is_empty()
 var active: bool = ready and bool(value.get("started",false)) and not bool(value.get("paused",false)) and not bool(value.get("closed",false))
 _match_header.visible=active
 if active:
  if heading.get_parent()!=_match_header: heading.reparent(_match_header)
  if _settings_toggle.get_parent()!=_match_header: _settings_toggle.reparent(_match_header)
  heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  _settings_toggle.size_flags_horizontal=Control.SIZE_SHRINK_END
  VisualSkin.icon_action(_settings_toggle,"settings",tr_pair("إعدادات الغرفة","Room settings"))
  _main_column.move_child(_match_header,_main_column.get_children().find(status)+1)
  _main_column.move_child(clock,_main_column.get_children().find(_match_header)+1)
  _main_column.move_child(_clock_bar,_main_column.get_children().find(clock)+1)
 else:
  if heading.get_parent()!=_main_column: heading.reparent(_main_column)
  if _settings_toggle.get_parent()!=_main_column: _settings_toggle.reparent(_main_column)
  _main_column.move_child(heading,_main_column.get_children().find(status)+1)
  _main_column.move_child(_settings_toggle,_main_column.get_children().find(_settings_body))
  _settings_toggle.text=tr_pair("إعدادات الغرفة والاتصال","Room & connection settings")
  _settings_toggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _main_column.get_node("CompactHeader").visible=not active
 _scores.visible=not active
 _seats.columns=6 if active else 3
 if active:
  if _seats.get_parent()!=_match_controls: _seats.reparent(_match_controls)
  _match_controls.move_child(_seats,_match_controls.get_children().find(_reply_row)+1)
  if not _was_active: _settings_body.hide()
 else:
  if _seats.get_parent()!=_main_column: _seats.reparent(_main_column)
  _main_column.move_child(_seats,_main_column.get_children().find(_settings_toggle))
 _was_active=active
 var pending: Dictionary = value.get("pending") if value.get("pending") is Dictionary else {}
 var turn: bool = active and int(value.get("current",-1)) == client.player and pending.is_empty()
 var responder: bool = active and int(pending.get("responder",-1)) == client.player
 create_button.disabled = not ready or not client.code.is_empty()
 join_button.disabled = create_button.disabled
 resume_button.disabled = client.token.is_empty() or ready
 question_button.disabled = not turn
 guess_button.disabled = not turn
 pass_button.disabled = not turn
 yes_button.disabled = not responder or pending.get("kind") != "question"
 no_button.disabled = yes_button.disabled
 correct_button.disabled = not responder or pending.get("kind") != "guess"
 wrong_button.disabled = correct_button.disabled
 for key in presets: presets[key].disabled = not turn or key not in value.get("preset_questions",[])
 chat_button.disabled = not ready or client.code.is_empty() or bool(value.get("closed",false))
 report_button.disabled = chat_button.disabled or not bool(client.capabilities.get("moderation",false))
 block_button.disabled = report_button.disabled
 heading.text = tr_pair("غرف الأصدقاء • 2–6 لاعبين","Friend rooms • 2–6 players") if client.code.is_empty() else tr_pair("الغرفة %s • اللاعب %d","Room %s • player %d") % [client.code,client.player+1]
 if active: heading.text=tr_pair("الدور: اللاعب %d","Turn: player %d") % (int(value.get("current",0))+1)
 clock.add_theme_font_size_override("font_size",28 if active else 18)
 var connected: Array = value.get("connected",[])
 var seats: int = int(value.get("capacity",players_field.get_selected_id()))
 var joined: int = int(value.get("joined",0))
 for i in range(6):
  _seat_panels[i].visible = i < seats
  _seat_labels[i].add_theme_font_size_override("font_size",11 if active else 14)
  _seat_avatars[i].custom_minimum_size=Vector2(24,24) if active else Vector2(36,36)
  var seat_skin=VisualSkin.card(Color("082033"),12)
  seat_skin.content_margin_left=4 if active else 18
  seat_skin.content_margin_right=4 if active else 18
  seat_skin.content_margin_top=8
  seat_skin.content_margin_bottom=8
  _seat_panels[i].add_theme_stylebox_override("panel",seat_skin)
  var occupied: bool = i < joined
  var online: bool = i < connected.size() and bool(connected[i])
  var name_value: String = tr_pair("اللاعب %d","Player %d") % (i+1)
  var score_value: int = int(value.get("scores",[])[i]) if i < value.get("scores",[]).size() else 0
  _seat_labels[i].text = name_value+ (tr_pair(" • أنت"," • You") if i==client.player and occupied else "")+"\n"+(str(score_value) if bool(value.get("started",false)) and occupied else (tr_pair("متصل","Connected") if online else (tr_pair("إعادة اتصال","Reconnecting") if occupied else tr_pair("مكان متاح","Open seat"))))
  _seat_labels[i].add_theme_color_override("font_color",Color("59ed9b") if online else Color("b4c4df"))
 var score_parts := PackedStringArray()
 var score_values: Array = value.get("scores",[])
 for index in range(score_values.size()): score_parts.append(str(index+1)+": "+str(score_values[index]))
 _scores.text = tr_pair("النقاط • ","Scores • ")+"  |  ".join(score_parts) if not score_parts.is_empty() else ""
 clock.visible = bool(value.get("started",false))
 _match_controls.visible = bool(value.get("started",false))
 _lobby_controls.visible = not active
 if bool(value.get("closed",false)): status.text = tr_pair("انتهت / أغلقت الغرفة","Match finished / room closed")
 elif bool(value.get("paused",false)): status.text = tr_pair("المباراة متوقفة حتى استعادة اتصال اللاعب","Match paused until player reconnects")
 elif not ready: status.text = tr_pair("خدمة الغرف غير متصلة؛ قد يكون تفعيلها معلقًا.","Room service is disconnected; activation may be pending.")
 elif not bool(value.get("started",false)): status.text = tr_pair("بانتظار اكتمال عدد اللاعبين","Waiting for the configured number of players")
 else: status.text = tr_pair("المباراة متصلة • المجيب المحدد: ","Match connected • designated respondent: ") + str(int(value.get("responder",0))+1)
 question_label.text = str(pending.get("text",""))
 question_label.visible=not pending.is_empty()
 var key: String = str(pending.get("question_id",""))
 if FACTS.has(key): question_label.text = str(FACTS[key][0 if language == "ar" else 1])
 for i in range(6): images[i].hide(); captions[i].hide()
 for opponent in value.get("opponents",[]):
  var index: int = int(opponent.player)
  var path: String = str(opponent.image)
  if index == int(value.get("responder",-1)) and index >= 0 and index < 6 and catalog.has(path) and ResourceLoader.exists(path):
   images[index].texture = load(path)
   images[index].show()
   captions[index].text = tr_pair("صورة اللاعب ","Player picture ") + str(index+1)+" • "+str(catalog[path].get(language,catalog[path].get("en","")))
   captions[index].show()
 var lines := PackedStringArray()
 for entry in value.get("chat",[]): lines.append(str(int(entry.player)+1)+": "+str(entry.text))
 for event in value.get("history",[]):
  if event.get("kind") in ["reply","confirmation"]: lines.append(str(int(event.player)+1)+": "+str(event.get("text",""))+" → "+tr_pair("نعم" if event.answer else "لا","Yes" if event.answer else "No"))
 chat_log.text = "\n".join(lines)
 _turn_ms=maxi(1000,int(value.get("timer",30))*1000)
 local_remaining = int(value.get("remaining_ms",-1)) if value.get("remaining_ms") != null else -1
 received_at = Time.get_ticks_msec()

func _process(_delta: float) -> void:
 if not is_instance_valid(client): return
 var left := local_remaining
 if left >= 0 and not bool(client.state.get("paused",false)): left = maxi(0,left-(Time.get_ticks_msec()-received_at))
 var seconds: int=ceili(left/1000.0)
 clock.text = tr_pair("بدون مؤقت","No timer") if left < 0 else "%02d:%02d" % [floori(seconds/60.0),seconds%60]
 _clock_bar.visible=clock.visible and left>=0
 _clock_bar.value=clampf(float(left)/float(_turn_ms)*100.0,0.0,100.0)

var _leaving_scene := false

func _home() -> void:
 if _leaving_scene or not is_inside_tree() or is_queued_for_deletion(): return
 _leaving_scene = true
 var scene_tree := get_tree()
 if is_instance_valid(client) and not client.capabilities.is_empty() and not client.code.is_empty(): client.send_action("duel_leave")
 var result := scene_tree.change_scene_to_file("res://scenes/Main.tscn")
 if result != OK: _leaving_scene = false

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST: _home.call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_BACK]:
  get_viewport().set_input_as_handled()
  _home.call_deferred()

func _connect_service() -> void:
 client.terms_accepted = terms.button_pressed
 client.connect_endpoint(endpoint_field.text.strip_edges())
 if not client.last_error.is_empty(): status.text=client.last_error

func _voice_changed() -> void:
 if not is_instance_valid(voice_adapter): return
 if not is_instance_valid(client):
  voice_button.disabled=true
  return
 voice_button.disabled = not voice_adapter.is_available() or not bool(client.capabilities.get("voice",false)) or not bool(client.state.get("started",false)) or bool(client.state.get("closed",false)) or bool(client.state.get("paused",false))
 VisualSkin.icon_action(voice_button,"mic" if voice_adapter.requested else "mic_off",tr_pair("كتم الميكروفون","Mute microphone") if voice_adapter.requested else tr_pair("تفعيل الميكروفون","Enable microphone"))
 if not voice_adapter.is_available(): voice_status.text = tr_pair("الصوت يتطلب نسخة Android وجهازًا متوافقًا؛ لم يتم التحقق على هاتف بعد.","Voice requires Android hardware; device verification is still pending.")
 elif voice_adapter.requested: voice_status.text = tr_pair("الصوت قيد التفعيل بموافقة اللاعبين","Voice enabling with player consent")
 else: voice_status.text = tr_pair("الميكروفون مكتوم؛ التفعيل اختياري","Microphone muted; enabling is optional")
