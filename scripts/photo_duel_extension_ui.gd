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


func tr_pair(ar: String, en: String) -> String:
 return ar if language == "ar" else en

func label(value: String, size: int = 18) -> Label:
 var control := Label.new()
 control.text = value
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
 control.custom_minimum_size.y = 54
 VisualSkin.decorate_button(control,"gold")
 control.pressed.connect(_invoke.bind(weakref(control),action),CONNECT_DEFERRED)
 column.add_child(control)
 return control

func _invoke(ref: WeakRef, action: Callable) -> void:
 var control: Variant = ref.get_ref()
 if is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(control) and control.is_inside_tree() and not control.is_queued_for_deletion() and not control.disabled:
  action.call()

func _ready() -> void:
 var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://progress_v10_all.json")) if FileAccess.file_exists("user://progress_v10_all.json") else null
 if saved is Dictionary: language = str(saved.get("language","ar"))
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guess_picture_302/catalog.json"))
 for item in data.items:
  if item.group == "original_200": catalog[str(item.image)] = item
 var bg := VisualSkin.new()
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(bg)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.scroll_deadzone = 22
 scroll.follow_focus = true
 add_child(scroll)
 var margin := MarginContainer.new()
 for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
 margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(margin)
 column = VBoxContainer.new()
 column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",10)
 margin.add_child(column)
 VisualSkin.add_brand_banner(column,"res://assets/ui/gaming_hub_brand.png",tr_pair("غرف الأصدقاء • خمن صورتك","Friend rooms • Guess Your Picture"))
 status = label(tr_pair("اختر إعدادات الغرفة واتصل بالخدمة عند تفعيلها.","Choose room settings and connect when the service is enabled."))
 heading = label("",24)
 clock = label("")
 endpoint_field = field(tr_pair("عنوان الخدمة المعتمد؛ لا يزال النشر معلقًا","Approved service address; deployment pending"))
 endpoint_field.text = Client.endpoint_from_args()
 label(tr_pair("الدردشة والصوت اختياريان. يمنع الإساءة والتهديد ونشر المعلومات الشخصية والمحتوى غير الملائم. يمكنك الإبلاغ وحظر لاعب. لا يبدأ الميكروفون دون موافقتك.","Chat and voice are optional. Abuse, threats, personal information and inappropriate content are prohibited. You can report or block players. The microphone requires your consent."),15)
 terms = CheckBox.new()
 terms.custom_minimum_size.y = 54
 terms.text = tr_pair("أوافق على قواعد الغرف واستخدام الدردشة","I accept the room and chat rules")
 column.add_child(terms)
 players_field = OptionButton.new()
 players_field.custom_minimum_size.y = 54
 for count in range(2,7): players_field.add_item(str(count),count)
 column.add_child(players_field)
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
 create_button = button(tr_pair("إنشاء غرفة","Create room"),func(): client.create_room(players_field.get_selected_id(),timer_field.get_selected_id(),int(target_field.value)))
 code_field = field(tr_pair("كود الغرفة","Room code"))
 join_button = button(tr_pair("انضمام بكود","Join by code"),func(): client.join_room(code_field.text))
 resume_button = button(tr_pair("استعادة الاتصال","Reconnect session"),func(): client.resume_session())
 button(tr_pair("الاتصال بخدمة الغرف","Connect to room service"),_connect_service)
 for i in range(6):
  captions.append(label(""))
  var picture := TextureRect.new()
  picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
  picture.custom_minimum_size.y = 180
  picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  column.add_child(picture)
  images.append(picture)
 question_label = label("")
 question_field = field(tr_pair("سؤال نصي للمجيب المحدد","Text question for the designated opponent"))
 question_button = button(tr_pair("إرسال السؤال","Send question"),func(): client.send_action("duel_question",{"text":question_field.text}))
 for key in FACTS:
  var fact: String = key
  presets[fact] = button(str(FACTS[fact][0 if language == "ar" else 1]),func(): client.send_action("duel_preset",{"question_id":fact}))
 yes_button = button(tr_pair("نعم","Yes"),func(): client.send_action("duel_reply",{"answer":true}))
 no_button = button(tr_pair("لا","No"),func(): client.send_action("duel_reply",{"answer":false}))
 guess_field = field(tr_pair("تخمينك؛ يؤكده المنافس المحدد","Your guess; confirmed by designated opponent"))
 guess_button = button(tr_pair("طلب تأكيد التخمين","Request guess confirmation"),func(): client.send_action("duel_guess",{"guess":guess_field.text}))
 correct_button = button(tr_pair("التخمين صحيح","Guess is correct"),func(): client.send_action("duel_confirm",{"correct":true}))
 wrong_button = button(tr_pair("التخمين خطأ","Guess is incorrect"),func(): client.send_action("duel_confirm",{"correct":false}))
 pass_button = button(tr_pair("تمرير الدور","Pass turn"),func(): client.send_action("duel_pass"))
 chat_log = label("")
 chat_field = field(tr_pair("دردشة نصية لجميع لاعبي الغرفة","Text chat for everyone in the room"))
 chat_field.max_length = 280
 chat_button = button(tr_pair("إرسال الدردشة","Send chat"),_chat)
 voice_button = button(tr_pair("تفعيل الميكروفون","Enable microphone"),func(): voice_adapter.enable(not voice_adapter.requested))
 voice_status = label("")
 target_player = OptionButton.new()
 target_player.custom_minimum_size.y = 54
 for index in range(6): target_player.add_item(tr_pair("اللاعب ","Player ")+str(index+1),index)
 column.add_child(target_player)
 report_reason = field(tr_pair("سبب الإبلاغ","Report reason"))
 report_button = button(tr_pair("الإبلاغ عن اللاعب","Report player"),func(): client.send_action("duel_report",{"target":target_player.get_selected_id(),"reason":report_reason.text}))
 block_button = button(tr_pair("حظر اللاعب ومغادرة الغرفة","Block player and leave room"),func(): client.send_action("duel_block",{"target":target_player.get_selected_id()}))
 button(tr_pair("مغادرة الغرفة","Leave room"),func(): client.send_action("duel_leave"))
 button(tr_pair("العودة إلى Gaming Hub","Back to Gaming Hub"),_home)
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

func _chat() -> void:
 if client.send_action("duel_chat",{"text":chat_field.text}) == OK: chat_field.clear()

func _state(value: Dictionary) -> void:
 var ready: bool = not client.capabilities.is_empty()
 var active: bool = ready and bool(value.get("started",false)) and not bool(value.get("paused",false)) and not bool(value.get("closed",false))
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
 heading.text = tr_pair("الغرفة %s • اللاعب %d • %d/%d متصلون • الدور %d • النقاط %s","Room %s • player %d • %d/%d joined • turn %d • scores %s") % [client.code,client.player+1,int(value.get("joined",0)),int(value.get("capacity",0)),int(value.get("current",0))+1,str(value.get("scores",[]))]
 if bool(value.get("closed",false)): status.text = tr_pair("انتهت / أغلقت الغرفة","Match finished / room closed")
 elif bool(value.get("paused",false)): status.text = tr_pair("المباراة متوقفة حتى استعادة اتصال اللاعب","Match paused until player reconnects")
 elif not ready: status.text = tr_pair("خدمة الغرف غير متصلة؛ قد يكون تفعيلها معلقًا.","Room service is disconnected; activation may be pending.")
 elif not bool(value.get("started",false)): status.text = tr_pair("بانتظار اكتمال عدد اللاعبين","Waiting for the configured number of players")
 else: status.text = tr_pair("المباراة متصلة • المجيب المحدد: ","Match connected • designated respondent: ") + str(int(value.get("responder",0))+1)
 question_label.text = str(pending.get("text",""))
 var key: String = str(pending.get("question_id",""))
 if FACTS.has(key): question_label.text = str(FACTS[key][0 if language == "ar" else 1])
 for i in range(6): images[i].hide(); captions[i].hide()
 for opponent in value.get("opponents",[]):
  var index: int = int(opponent.player)
  var path: String = str(opponent.image)
  if index >= 0 and index < 6 and catalog.has(path) and ResourceLoader.exists(path):
   images[index].texture = load(path)
   images[index].show()
   captions[index].text = tr_pair("صورة اللاعب ","Player picture ") + str(index+1)
   captions[index].show()
 var lines := PackedStringArray()
 for entry in value.get("chat",[]): lines.append(str(int(entry.player)+1)+": "+str(entry.text))
 for event in value.get("history",[]):
  if event.get("kind") in ["reply","confirmation"]: lines.append(str(int(event.player)+1)+": "+str(event.get("text",""))+" → "+tr_pair("نعم" if event.answer else "لا","Yes" if event.answer else "No"))
 chat_log.text = "\n".join(lines)
 local_remaining = int(value.get("remaining_ms",-1)) if value.get("remaining_ms") != null else -1
 received_at = Time.get_ticks_msec()

func _process(_delta: float) -> void:
 if not is_instance_valid(client): return
 var left := local_remaining
 if left >= 0 and not bool(client.state.get("paused",false)): left = maxi(0,left-(Time.get_ticks_msec()-received_at))
 clock.text = tr_pair("بدون مؤقت","No timer") if left < 0 else tr_pair("المتبقي: %d ثانية","Remaining: %d seconds") % ceili(left/1000.0)

func _home() -> void:
 if is_instance_valid(client) and not client.capabilities.is_empty() and not client.code.is_empty(): client.send_action("duel_leave")
 get_tree().change_scene_to_file("res://scenes/Main.tscn")

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
 voice_button.text = tr_pair("كتم الميكروفون","Mute microphone") if voice_adapter.requested else tr_pair("تفعيل الميكروفون","Enable microphone")
 if not voice_adapter.is_available(): voice_status.text = tr_pair("الصوت يتطلب نسخة Android وجهازًا متوافقًا؛ لم يتم التحقق على هاتف بعد.","Voice requires Android hardware; device verification is still pending.")
 elif voice_adapter.requested: voice_status.text = tr_pair("الصوت قيد التفعيل بموافقة اللاعبين","Voice enabling with player consent")
 else: voice_status.text = tr_pair("الميكروفون مكتوم؛ التفعيل اختياري","Microphone muted; enabling is optional")
