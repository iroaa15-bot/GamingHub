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
var _invite_box: VBoxContainer
var _invite_code: LineEdit
var _copy_code_button: Button
var _advanced_connection: VBoxContainer
var _pending_room_action := ""
var _pending_join_code := ""
var _online_category: OptionButton
var _online_rank: OptionButton
var _online_filter_box: VBoxContainer
var _online_category_keys: Array=["all"]
var _online_rank_keys: Array=["easy","medium","hard"]
var _agreement_box: VBoxContainer
var _agreement_info: Label
var _mode_field: OptionButton
var _propose_button: Button
var _accept_button: Button
var _start_button: Button
var _preset_body: VBoxContainer
var _preset_toggle: Button
var _text_reply_field: LineEdit
var _text_reply_button: Button
var _chat_body: VBoxContainer
var _chat_toggle: Button
var _displayed_mode := ""
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
var voice_mute_button: Button
var _voice_controls: VBoxContainer
var _voice_question: Button
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
  load("res://scripts/room_audio_policy.gd").acquire(get_tree()).effect("navigation" if control.text.contains("العودة") else "click",true)
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
 column = _section(tr_pair("خيارات الغرفة","Room options"))
 _settings_body=column
 _settings_toggle=main_column.get_child(settings_index)
 var room_settings_column := column
 var advanced_index := column.get_child_count()
 column=_section(tr_pair("إعداد اتصال الاختبار","Test connection setup"))
 _advanced_connection=column
 room_settings_column.get_child(advanced_index).visible=OS.has_feature("debug")
 endpoint_field = field(tr_pair("عنوان الخدمة المعتمد؛ لا يزال النشر معلقًا","Approved service address; deployment pending"))
 endpoint_field.text = Client.endpoint_from_args()
 endpoint_field.layout_direction = Control.LAYOUT_DIRECTION_LTR
 endpoint_field.text_changed.connect(func(_text: String):
  if is_instance_valid(client):_state(client.state))
 label(tr_pair("الدردشة والصوت اختياريان. يمنع الإساءة والتهديد ونشر المعلومات الشخصية والمحتوى غير الملائم. يمكنك الإبلاغ وحظر لاعب. لا يبدأ الميكروفون دون موافقتك.","Chat and voice are optional. Abuse, threats, personal information and inappropriate content are prohibited. You can report or block players. The microphone requires your consent."),15)
 terms = CheckBox.new()
 terms.custom_minimum_size.y = 54
 terms.text = tr_pair("أوافق على قواعد الغرف واستخدام الدردشة","I accept the room and chat rules")
 column.add_child(terms)
 var test_connect := button(tr_pair("فحص اتصال الاختبار","Test connection"),_connect_service)
 test_connect.tooltip_text=tr_pair("للتطوير المحلي فقط","Local development only")
 column=room_settings_column
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
 _online_filter_box=VBoxContainer.new()
 column.add_child(_online_filter_box)
 var prior_column := column
 column=_online_filter_box
 label(tr_pair("١ • اختر الصعوبة مرة واحدة قبل إنشاء الغرفة","1 • Choose difficulty once before creating a room"))
 _online_category=OptionButton.new()
 _online_category.custom_minimum_size.y=54
 column.add_child(_online_category)
 _online_rank=OptionButton.new()
 _online_rank.custom_minimum_size.y=54
 column.add_child(_online_rank)
 for rank in ["سهل","متوسط","صعب"] if language=="ar" else ["Easy","Medium","Hard"]: _online_rank.add_item(rank)
 _online_rank.select(1)
 column=prior_column
 column = main_column
 _lobby_controls = VBoxContainer.new()
 _lobby_controls.add_theme_constant_override("separation",8)
 main_column.add_child(_lobby_controls)
 _online_filter_box.reparent(_lobby_controls)
 column = _lobby_controls
 terms.reparent(_lobby_controls)
 terms.text=tr_pair("أوافق على قواعد الغرف والدردشة","I accept the room and chat rules")
 terms.tooltip_text=tr_pair("الصوت اختياري ولا يبدأ دون إذن الميكروفون؛ يمنع الإساءة ونشر المعلومات الشخصية.","Voice is optional and requires microphone permission; abuse and sharing personal information are prohibited.")
 create_button = button(tr_pair("إنشاء غرفة","Create room"),func(): _request_room_action("create"))
 code_field = field(tr_pair("كود الغرفة","Room code"))
 code_field.layout_direction = Control.LAYOUT_DIRECTION_LTR
 code_field.max_length=12
 join_button = button(tr_pair("انضمام بالكود","Join with code"),func(): _request_room_action("join"))
 resume_button = button(tr_pair("استعادة الاتصال","Reconnect session"),func(): client.resume_session())
 resume_button.reparent(_settings_body)
 _invite_box=VBoxContainer.new()
 main_column.add_child(_invite_box)
 column=_invite_box
 label(tr_pair("كود الغرفة","Room code"),16)
 _invite_code=LineEdit.new()
 _invite_code.editable=false
 _invite_code.custom_minimum_size.y=56
 _invite_code.add_theme_font_size_override("font_size",28)
 column.add_child(_invite_code)
 _invite_code.layout_direction=Control.LAYOUT_DIRECTION_LTR
 _invite_code.alignment=HORIZONTAL_ALIGNMENT_CENTER
 _copy_code_button=button(tr_pair("نسخ الكود للمشاركة","Copy code to share"),_copy_room_code)
 column=main_column
 _agreement_box=VBoxContainer.new()
 _agreement_box.add_theme_constant_override("separation",8)
 main_column.add_child(_agreement_box)
 column=_agreement_box
 _agreement_info=label("")
 _online_category.reparent(_agreement_box)
 _mode_field=OptionButton.new()
 _mode_field.custom_minimum_size.y=54
 for title in ["صوت • أسئلة شفهية","نص • سؤال وجواب مكتوب","نقر • أسئلة جاهزة"] if language=="ar" else ["Voice • spoken questions","Text • written questions and answers","Tap • preset questions"]: _mode_field.add_item(title)
 _mode_field.select(2)
 column.add_child(_mode_field)
 _propose_button=button(tr_pair("اقتراح الصنف وطريقة اللعب","Propose category & mode"),_propose_configuration)
 _accept_button=button(tr_pair("أوافق على الصعوبة والصنف وطريقة اللعب","Accept difficulty, category & mode"),_accept_configuration)
 _start_button=button(tr_pair("ابدأ اللعبة","Start game"),func(): client.send_action("duel_start"))
 column=main_column
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
 _voice_question=button(tr_pair("طلب إجابة نعم / لا","Request Yes / No answer"),func(): client.send_action("duel_voice_question"))
 question_field = field(tr_pair("سؤال نصي للمجيب المحدد","Text question for the designated opponent"))
 question_button = button(tr_pair("إرسال السؤال","Send question"),func(): client.send_action("duel_question",{"text":question_field.text}))
 var match_column := column
 var preset_index := column.get_child_count()
 column = _section(tr_pair("الأسئلة الجاهزة","Preset questions"))
 _preset_body=column
 _preset_toggle=match_column.get_child(preset_index)
 for key in FACTS:
  var fact: String = key
  presets[fact] = button(str(FACTS[fact][0 if language == "ar" else 1]),func(): client.send_action("duel_preset",{"question_id":fact}))
 column = match_column
 _text_reply_field=field(tr_pair("اكتب إجابتك للسائل","Write your answer to the asker"))
 _text_reply_button=button(tr_pair("إرسال الإجابة","Send answer"),func():
  if client.send_action("duel_text_reply",{"text":_text_reply_field.text})==OK: _text_reply_field.clear())
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
 pass_button.reparent(_settings_body)
 var chat_index := column.get_child_count()
 column = _section(tr_pair("الدردشة النصية","Text chat"))
 _chat_body=column
 _chat_toggle=match_column.get_child(chat_index)
 chat_log = label("")
 chat_field = field(tr_pair("دردشة نصية لجميع لاعبي الغرفة","Text chat for everyone in the room"))
 chat_field.max_length = 280
 chat_button = button(tr_pair("إرسال الدردشة","Send chat"),_chat)
 column = match_column
 _voice_controls=VBoxContainer.new()
 main_column.add_child(_voice_controls)
 column=_voice_controls
 voice_button = button(tr_pair("اتصال الصوت","Voice connection"),func(): voice_adapter.enable(not voice_adapter.requested))
 voice_mute_button=button(tr_pair("كتم إرسال الميكروفون","Mute microphone transmission"),func(): voice_adapter.set_muted(not voice_adapter.muted))
 var voice_row := HBoxContainer.new()
 voice_row.add_theme_constant_override("separation",12)
 column.add_child(voice_row)
 voice_button.reparent(voice_row)
 voice_mute_button.reparent(voice_row)
 for control in [voice_button,voice_mute_button]:control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 voice_status = label("")
 column=_settings_body
 column = _section(tr_pair("الإبلاغ والحظر","Report & block"))
 target_player = OptionButton.new()
 target_player.custom_minimum_size.y = 54
 for index in range(6): target_player.add_item(tr_pair("اللاعب ","Player ")+str(index+1),index)
 column.add_child(target_player)
 report_reason = field(tr_pair("سبب الإبلاغ","Report reason"))
 report_button = button(tr_pair("الإبلاغ عن اللاعب","Report player"),func(): client.send_action("duel_report",{"target":target_player.get_selected_id(),"reason":report_reason.text}))
 block_button = button(tr_pair("حظر اللاعب ومغادرة الغرفة","Block player and leave room"),func(): client.send_action("duel_block",{"target":target_player.get_selected_id()}))
 column = main_column
 var back_button := button(tr_pair("مغادرة والعودة للألعاب","Leave & return to games"),_home)
 back_button.icon = VisualSkin.menu_icon("back")
 back_button.expand_icon = true
 back_button.add_theme_constant_override("icon_max_width",22)
 client = Client.new()
 add_child(client)
 client.state_changed.connect(_state)
 client.protocol_ready.connect(_room_protocol_ready)
 client.event_received.connect(func(message: Dictionary):
  if message.get("type") == "duel_error":
   _pending_room_action=""
   status.text = str(message.get("message",""))
  elif message.get("type") == "duel_reported": status.text = tr_pair("حُفظ البلاغ: ","Report saved: ")+str(message.get("report_id",""))
  elif message.get("type") == "duel_blocked": status.text = tr_pair("تم حظر اللاعب","Player blocked")
 )
 client.connection_changed.connect(func(_ready: bool): _state(client.state))
 voice_adapter = load("res://scripts/photo_duel_voice_adapter.gd").new()
 add_child(voice_adapter)
 voice_adapter.attach(client)
 voice_adapter.changed.connect(_voice_changed)
 voice_adapter.unavailable.connect(func(reason: String): voice_status.text = reason)
 # Connection is initiated by Create/Join; players never need a separate Connect step.
 _state({})
 _voice_changed()
 VisualSkin.compact_menu(main_column)
 VisualSkin.decorate_button(yes_button,"teal")
 VisualSkin.decorate_button(no_button,"danger")
 VisualSkin.decorate_button(guess_button,"amber")
 for primary in [yes_button,no_button,guess_button]:
  primary.add_theme_font_size_override("font_size",14)
 for option in [_online_category,_online_rank,_mode_field,players_field,timer_field]:
  VisualSkin.decorate_selector(option)
  option.add_theme_font_size_override("font_size",16)
 VisualSkin.enable_menu_swipe(column)

func _chat() -> void:
 if client.send_action("duel_chat",{"text":chat_field.text}) == OK: chat_field.clear()

func _state(value: Dictionary) -> void:
 load("res://scripts/room_audio_policy.gd").acquire(get_tree()).room_snapshot(self,value)
 var ready: bool = not client.capabilities.is_empty()
 var active: bool = ready and bool(value.get("started",false)) and not bool(value.get("paused",false)) and not bool(value.get("closed",false)) and not bool(value.get("match_finished",false))
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
  var body_index: int=_main_column.get_children().find(_settings_body)
  if _settings_toggle.get_index()<body_index: body_index-=1
  _main_column.move_child(_settings_toggle,body_index)
  _settings_toggle.text=tr_pair("خيارات الغرفة","Room options")
  _settings_toggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _main_column.get_node("CompactHeader").visible=not active
 _scores.visible=not active and bool(value.get("started",false))
 _seats.columns=6 if active else 3
 _seats.visible=not client.code.is_empty()
 heading.visible=not client.code.is_empty()
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
 var service_available: bool=Client.allowed_endpoint(endpoint_field.text.strip_edges())
 create_button.disabled = not client.code.is_empty() or (not ready and not service_available) or (ready and not bool(client.capabilities.get("room_agreement",false)))
 var agreement: bool=bool(value.get("room_agreement",false))
 var in_room: bool=not client.code.is_empty()
 _online_filter_box.visible=not in_room
 if _online_category.item_count==0 and client.capabilities.get("picture_categories") is Dictionary:
  _online_category.add_item(tr_pair("كل الصور","All pictures"))
  for key in client.capabilities.picture_categories:
   var names: Variant=client.capabilities.picture_categories[key]
   if not names is Dictionary: continue
   _online_category_keys.append(key)
   _online_category.add_item(str(names.get(language,names.get("en",key))))
 _agreement_box.visible=agreement and in_room and not bool(value.get("started",false)) and not bool(value.get("closed",false))
 _online_category.visible=_agreement_box.visible
 var host: bool=client.player==int(value.get("host",0))
 var mode: String=str(value.get("primary_mode","tap"))
 if agreement:
  var category_index: int=_online_category_keys.find(value.get("picture_category","all"))
  if category_index>=0: _online_category.select(category_index)
  _mode_field.select(["voice","text","tap"].find(mode))
  _mode_field.set_item_disabled(0,not bool(client.capabilities.get("voice",false)))
  _online_category.disabled=not host
  _mode_field.disabled=not host
  _propose_button.visible=host
  var confirmations: Array=value.get("confirmed",[])
  var confirmed_count: int=confirmations.count(true)
  var names: Dictionary=client.capabilities.get("picture_difficulties",{}).get(value.get("picture_difficulty","all"),{})
  _agreement_info.text=tr_pair("٢ • اتفاق الغرفة\nالصعوبة: %s • التأكيدات %d/%d","2 • Room agreement\nDifficulty: %s • confirmations %d/%d") % [str(names.get(language,names.get("en",value.get("picture_difficulty","")))),confirmed_count,int(value.get("capacity",2))]
  _accept_button.disabled=client.player<0 or client.player>=confirmations.size() or bool(confirmations[client.player])
  _start_button.visible=host
  _start_button.disabled=confirmed_count!=int(value.get("capacity",2)) or bool(value.get("paused",false)) or int(value.get("joined",0))!=int(value.get("capacity",2))
 _online_rank.disabled=in_room
 join_button.disabled = create_button.disabled
 resume_button.disabled = client.token.is_empty() or ready
 resume_button.visible=not client.token.is_empty() and not ready
 var mode_text: bool=not agreement or mode=="text"
 var mode_tap: bool=not agreement or mode=="tap"
 question_field.visible=mode_text and turn
 question_button.visible=mode_text and turn
 _preset_toggle.visible=mode_tap
 _preset_toggle.icon=VisualSkin.menu_icon("list")
 _preset_toggle.expand_icon=true
 _preset_toggle.add_theme_constant_override("icon_max_width",22)
 if not mode_tap or not active or _displayed_mode!=mode: _preset_body.hide()
 _displayed_mode=mode
 _text_reply_field.visible=agreement and mode=="text" and responder and pending.get("kind")=="question"
 _text_reply_button.visible=_text_reply_field.visible
 _text_reply_button.disabled=not responder
 yes_button.visible=(not agreement or mode!="text") and responder and pending.get("kind")=="question"
 no_button.visible=yes_button.visible
 _chat_toggle.visible=not agreement or mode=="text"
 _chat_body.visible=agreement and mode=="text" and active
 _voice_controls.visible=not client.code.is_empty() and not bool(value.get("closed",false)) and (not agreement or mode=="voice")
 _voice_question.visible=active and mode=="voice" and turn
 if mode=="voice" and pending.get("kind")=="question": question_label.text=tr_pair("سؤال صوتي • أجب بنعم أو لا","Voice question • answer Yes or No")
 question_button.disabled = not turn
 guess_button.disabled = not turn
 guess_button.visible=turn
 guess_field.visible=turn
 pass_button.visible=turn
 pass_button.disabled = not turn
 yes_button.disabled = not responder or pending.get("kind") != "question"
 no_button.disabled = yes_button.disabled
 correct_button.disabled = not responder or pending.get("kind") != "guess"
 wrong_button.disabled = correct_button.disabled
 correct_button.visible=not correct_button.disabled
 wrong_button.visible=not wrong_button.disabled
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
  if not bool(value.get("started",false)) and occupied and agreement:
   var confirmations: Array=value.get("confirmed",[])
   _seat_labels[i].text=name_value+(tr_pair(" • أنت"," • You") if i==client.player else "")+"\n"+(tr_pair("جاهز","Ready") if i<confirmations.size() and confirmations[i] else tr_pair("بانتظار الموافقة","Awaiting agreement"))
  _seat_labels[i].add_theme_color_override("font_color",Color("59ed9b") if online else Color("b4c4df"))
 var score_parts := PackedStringArray()
 var score_values: Array = value.get("scores",[])
 for index in range(score_values.size()): score_parts.append(str(index+1)+": "+str(score_values[index]))
 _scores.text = tr_pair("النقاط • ","Scores • ")+"  |  ".join(score_parts) if not score_parts.is_empty() else ""
 clock.visible = bool(value.get("started",false)) and not bool(value.get("match_finished",false))
 _match_controls.visible = bool(value.get("started",false)) and not bool(value.get("match_finished",false))
 _lobby_controls.visible = client.code.is_empty()
 _invite_box.visible=not client.code.is_empty() and not active and not bool(value.get("closed",false))
 _invite_code.text=client.code
 _copy_code_button.disabled=client.code.is_empty()
 if _invite_box.visible:
  _main_column.move_child(_invite_box,_main_column.get_children().find(heading)+1)
  heading.text=tr_pair("أنت اللاعب %d","You are player %d") % (client.player+1)
 if bool(value.get("match_finished",false)): status.text=tr_pair("انتهت المباراة • الفائز: اللاعب %d • الصوت متاح حتى المغادرة","Match finished • winner: player %d • voice remains available until exit") % (int(value.get("winner",0))+1)
 elif bool(value.get("closed",false)): status.text = tr_pair("انتهت / أغلقت الغرفة","Match finished / room closed")
 elif bool(value.get("paused",false)): status.text = tr_pair("المباراة متوقفة حتى استعادة اتصال اللاعب","Match paused until player reconnects")
 elif not ready: status.text=tr_pair("خدمة غرف 2–6 لم تُفعّل بعد. الغرفة الكلاسيكية متاحة من صفحة اللعبة.","Rooms for 2–6 are not activated yet. Classic rooms remain available on the game page.") if not service_available else tr_pair("أنشئ غرفة أو أدخل كود صديقك","Create a room or enter your friend’s code")
 elif not bool(client.capabilities.get("room_agreement",false)): status.text=tr_pair("هذه الخدمة لا تدعم اتفاق الغرفة؛ استخدم الخدمة المحلية المتوافقة أو الغرفة الكلاسيكية المنفصلة.","This service does not support room agreement; use the compatible local service or the separate classic room.")
 elif not bool(value.get("started",false)): status.text = tr_pair("بانتظار اكتمال عدد اللاعبين","Waiting for the configured number of players")
 else: status.text = tr_pair("المباراة متصلة • المجيب المحدد: ","Match connected • designated respondent: ") + str(int(value.get("responder",0))+1)
 question_label.text = str(pending.get("text",""))
 question_label.visible=not pending.is_empty()
 if mode=="voice" and pending.get("kind")=="question":question_label.text=tr_pair("سؤال صوتي • أجب بنعم أو لا","Voice question • answer Yes or No")
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
  if event.get("kind")=="text_reply": lines.append(str(int(event.player)+1)+": "+str(event.get("text",""))+" → "+str(event.get("answer_text","")))
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
 if seconds in [1,2,3] and seconds!=_countdown_second and clock.visible and not bool(client.state.get("paused",false)):
  _countdown_second=seconds;load("res://scripts/room_audio_policy.gd").acquire(get_tree()).effect("countdown")
 clock.text = tr_pair("بدون مؤقت","No timer") if left < 0 else "%02d:%02d" % [floori(seconds/60.0),seconds%60]
 _clock_bar.visible=clock.visible and left>=0
 _clock_bar.value=clampf(float(left)/float(_turn_ms)*100.0,0.0,100.0)

var _countdown_second: int=-1
var _leaving_scene := false

func _home() -> void:
 if _leaving_scene or not is_inside_tree() or is_queued_for_deletion(): return
 _leaving_scene = true
 var scene_tree := get_tree()
 if is_instance_valid(voice_adapter):voice_adapter.enable(false)
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
 # This agreement UI uses the authenticated local service; generic clients retain old opt-in behavior.
 client.authenticate_local=endpoint_field.text.strip_edges().begins_with("ws://")
 client.connect_endpoint(endpoint_field.text.strip_edges())
 if not client.last_error.is_empty(): status.text=client.last_error

func _voice_changed() -> void:
 if not is_instance_valid(voice_adapter): return
 if not is_instance_valid(client):
  voice_button.disabled=true
  return
 voice_button.disabled = not voice_adapter.is_available() or not bool(client.capabilities.get("voice",false)) or client.code.is_empty() or bool(client.state.get("closed",false)) or bool(client.state.get("paused",false))
 voice_mute_button.disabled=not voice_adapter.requested
 VisualSkin.icon_action(voice_button,"phone_off" if voice_adapter.requested else "phone",tr_pair("إنهاء اتصال الصوت","End voice connection") if voice_adapter.requested else tr_pair("بدء اتصال الصوت","Start voice connection"))
 VisualSkin.icon_action(voice_mute_button,"mic_off" if voice_adapter.muted else "mic",tr_pair("إلغاء كتم الإرسال","Unmute transmission") if voice_adapter.muted else tr_pair("كتم إرسال الميكروفون","Mute microphone transmission"))
 if not voice_adapter.is_available(): voice_status.text=tr_pair("الصوت يحتاج Android وإذن الميكروفون؛ التحقق السمعي على هاتفين لم يكتمل.","Voice requires Android and microphone permission; two-device acoustic verification is pending.")
 elif voice_adapter.requested and not voice_adapter.bridge.active:voice_status.text=tr_pair("بانتظار موافقة الطرف الآخر أو استعادة الصوت","Waiting for peer consent or audio recovery")
 elif voice_adapter.requested:voice_status.text=tr_pair("إرسال الميكروفون مكتوم • الاستقبال متاح","Microphone transmission muted • receiving remains available") if voice_adapter.muted else tr_pair("جلسة الصوت مفعلة طوال عضوية الغرفة","Voice enabled throughout room membership")
 else:voice_status.text=tr_pair("الصوت اختياري • ابدأ الاتصال لمنح إذن الميكروفون","Voice is optional • start connection to grant microphone permission")

func _create_filtered_room() -> void:
 var rank: String=_online_rank_keys[_online_rank.selected] if _online_rank.selected>=0 else "medium"
 client.create_room(players_field.get_selected_id(),timer_field.get_selected_id(),int(target_field.value),{"picture_category":"all","picture_difficulty":rank})

func _propose_configuration() -> void:
 var category: String=_online_category_keys[_online_category.selected] if _online_category.selected>=0 else "all"
 client.send_action("duel_propose",{"picture_category":category,"primary_mode":["voice","text","tap"][_mode_field.selected]})

func _accept_configuration() -> void:
 client.send_action("duel_accept",{"config_revision":int(client.state.get("config_revision",-1)),"picture_difficulty":client.state.get("picture_difficulty","")})

func _copy_room_code() -> void:
 if client.code.is_empty():return
 var code: String=client.code
 DisplayServer.clipboard_set(code)
 await get_tree().process_frame
 if not is_inside_tree() or client.code!=code:return
 if DisplayServer.clipboard_get()==code:
  status.text=tr_pair("تم نسخ الكود • أرسله لصديقك ليدخل به الغرفة","Code copied • send it to your friend to join")
 else:
  _invite_code.grab_focus()
  _invite_code.select_all()
  status.text=tr_pair("تعذر النسخ التلقائي • الكود محدد للنسخ يدويًا","Automatic copy unavailable • code selected for manual copy")

func _request_room_action(kind: String) -> void:
 if not client.code.is_empty():return
 if not terms.button_pressed:
  status.text=tr_pair("وافق على قواعد الغرف أولًا","Accept the room rules first")
  return
 if kind=="join":
  var normalized: String=code_field.text.strip_edges().replace(" ","").replace("-","").to_upper()
  var pattern := RegEx.new()
  pattern.compile("^[A-F0-9]{8}$")
  if pattern.search(normalized)==null:
   status.text=tr_pair("أدخل كود الغرفة المكوّن من 8 حروف وأرقام","Enter the 8-character room code")
   return
  _pending_join_code=normalized
 _pending_room_action=kind
 if not client.capabilities.is_empty():_room_protocol_ready(client.capabilities)
 else:
  status.text=tr_pair("جار الاتصال…","Connecting…")
  _connect_service()

func _room_protocol_ready(capabilities: Dictionary) -> void:
 if _pending_room_action.is_empty():return
 if not bool(capabilities.get("room_agreement",false)):
  _pending_room_action=""
  status.text=tr_pair("هذه الخدمة لا تدعم الغرف المطلوبة","This service does not support these rooms")
  return
 var action: String=_pending_room_action
 _pending_room_action=""
 if action=="create":_create_filtered_room()
 elif action=="join":client.join_room(_pending_join_code)
