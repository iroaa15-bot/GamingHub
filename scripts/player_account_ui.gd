extends VBoxContainer
signal back_requested
signal progress_received(value: Dictionary)
const MenuSkin=preload("res://scripts/visual_skin.gd")
var local_progress: Dictionary={}
var language := "ar"
var _column: VBoxContainer
var _auth_group: VBoxContainer
var _profile_group: VBoxContainer
var _friends_group: VBoxContainer
var client: Node
var status: Label
var email: LineEdit
var password: LineEdit
var display_name: LineEdit
var friend_id: LineEdit
var room_code: LineEdit
var listing: Label
var admin: Button
var _profile_name: Label
var _xp_bar: ProgressBar
func _ready() -> void:
 _column=self
 layout_direction=Control.LAYOUT_DIRECTION_RTL if language=="ar" else Control.LAYOUT_DIRECTION_LTR
 add_theme_constant_override("separation",8)
 client=get_tree().root.get_node_or_null("PlayerAccountSession")
 if client==null:
  client=load("res://scripts/player_account_client.gd").new()
  client.name="PlayerAccountSession"
  get_tree().root.add_child(client)
 client.changed.connect(_result)
 MenuSkin.compact_header(self,_t("حسابي • Gaming Hub"))
 var profile_card:=PanelContainer.new()
 profile_card.add_theme_stylebox_override("panel",MenuSkin.card(Color("0b1649"),18));add_child(profile_card)
 var profile_stack:=VBoxContainer.new();profile_stack.add_theme_constant_override("separation",8);profile_card.add_child(profile_stack)
 _profile_name=Label.new();_profile_name.text=str(client.user.get("name","ضيف" if language=="ar" else "Guest"));_profile_name.add_theme_font_size_override("font_size",24);profile_stack.add_child(_profile_name)
 var xp: int=maxi(0,int(local_progress.get("xp",0)))
 var level:=Label.new();level.text=("المستوى %d • %d XP" if language=="ar" else "Level %d • %d XP") % [1+floori(xp/100.0),xp];profile_stack.add_child(level)
 _xp_bar=ProgressBar.new();_xp_bar.show_percentage=false;_xp_bar.value=xp%100;_xp_bar.custom_minimum_size.y=12;profile_stack.add_child(_xp_bar)
 var stats:=Label.new();stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 stats.text=("%d انتصارات  •  %d مباريات" if language=="ar" else "%d wins  •  %d matches") % [int(local_progress.get("wins",0)),int(local_progress.get("matches",0))];profile_stack.add_child(stats)
 status=Label.new()
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 status.text="الحساب اختياري. تقدم الضيف المحلي محفوظ. لا تُحفظ كلمات المرور أو رموز الجلسة على الجهاز." if language=="ar" else "Accounts are optional. Local guest progress is preserved. Passwords and session tokens are not saved on this device."
 add_child(status)
 _button("الاستمرار كضيف محلي",func(): back_requested.emit.call_deferred())
 _button("الحساب وتسجيل الدخول",func(): _auth_group.visible=not _auth_group.visible)
 _auth_group=VBoxContainer.new()
 _auth_group.visible=false
 add_child(_auth_group)
 _column=_auth_group
 display_name=_field("اسم اللاعب")
 email=_field("البريد الإلكتروني")
 email.layout_direction=Control.LAYOUT_DIRECTION_LTR
 password=_field("كلمة المرور • 12 حرفًا على الأقل")
 password.secret=true
 password.layout_direction=Control.LAYOUT_DIRECTION_LTR
 _button("دخول حساب Gaming Hub",func(): _credentials("/auth/login"))
 _button("إنشاء حساب Gaming Hub",func(): _credentials("/auth/register"))
 _button("جلسة ضيف على الخدمة المحلية",func(): client.request("/auth/guest",{"name":display_name.text if not display_name.text.is_empty() else "Guest"}))
 for provider in ["Google","Facebook"]:
  var provider_button := _button("الدخول عبر "+provider,func(): pass)
  provider_button.disabled=true
  provider_button.tooltip_text="يتطلب إعداد OAuth معتمدًا؛ لم يتم تكوينه بعد"
 _column=self
 _profile_group=_section(_t("تقدم الحساب وربطه"))
 _column=_profile_group
 _button("حفظ تقدمي في الحساب",func(): client.sync_progress(local_progress))
 _button("استعادة تقدم الحساب",func(): client.request("/me",{},false))
 _button("ربط جلسة الضيف السابقة بالحساب الحالي",func(): client.request("/auth/link-guest",{"guest_token":client.guest_token}))
 _column=self
 _friends_group=_section(_t("الأصدقاء والدعوات"))
 _column=_friends_group
 friend_id=_field("معرف الصديق • يظهر معرفك بعد تسجيل الدخول")
 _button("إرسال طلب صداقة",func(): client.request("/friends/request",{"user_id":friend_id.text}))
 _button("قبول طلب هذا الصديق",func(): client.request("/friends/accept",{"user_id":friend_id.text}))
 _button("عرض الأصدقاء والطلبات",func(): client.request("/friends",{},false))
 room_code=_field("كود الغرفة الحالي لدعوة الصديق")
 room_code.layout_direction=Control.LAYOUT_DIRECTION_LTR
 _button("دعوة الصديق للغرفة",func(): client.request("/invites",{"user_id":friend_id.text,"code":room_code.text}))
 _button("نسخ كود دعوة الغرفة",func(): DisplayServer.clipboard_set(room_code.text))
 _button("عرض الدعوات الواردة",func(): client.request("/invites",{},false))
 listing=Label.new()
 listing.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 _column.add_child(listing)
 _column=self
 admin=_button("لوحة الإدارة • وصول مخول",func(): OS.shell_open(client.endpoint))
 admin.visible=not client.token.is_empty() and not client.endpoint.is_empty() and client.user.get("role","")=="super_admin"
 _button("تسجيل خروج الحساب",func(): client.request("/auth/logout"))
 _button("العودة",func(): back_requested.emit.call_deferred())
 MenuSkin.compact_menu(self)
func _field(hint: String) -> LineEdit:
 var input := LineEdit.new()
 input.placeholder_text=_t(hint)
 input.custom_minimum_size.y=56
 MenuSkin.decorate_input(input)
 _column.add_child(input)
 return input
func _button(title: String, action: Callable) -> Button:
 var control := Button.new()
 control.text=_t(title)
 control.custom_minimum_size.y=56
 MenuSkin.decorate_button(control)
 control.pressed.connect(_invoke.bind(action),CONNECT_DEFERRED)
 _column.add_child(control)
 return control
func _invoke(action: Callable) -> void:
 if not is_inside_tree() or is_queued_for_deletion(): return
 var ancestor: Node=get_parent()
 while ancestor!=null:
  if ancestor is ScrollContainer:
   for observer in ancestor.get_children():
    if observer.has_method("dispatch"):
     observer.dispatch(action)
     return
   break
  ancestor=ancestor.get_parent()
 action.call()
func _credentials(route: String) -> void:
 client.request(route,{"email":email.text,"password":password.text,"name":display_name.text})
 password.clear()
func _result(route: String, data: Dictionary, ok: bool) -> void:
 if not is_inside_tree(): return
 status.text=str(data.get("error","تم الاتصال بالحساب المحلي")) if not ok else "الحساب: "+str(client.user.get("name",""))+" • "+str(client.user.get("id",""))
 admin.visible=not client.token.is_empty() and not client.endpoint.is_empty() and client.user.get("role","")=="super_admin"
 if ok and route in ["/me","/auth/link-guest"] and data.get("progress") is Dictionary: progress_received.emit(data.progress)
 _profile_name.text=str(client.user.get("name","ضيف" if language=="ar" else "Guest"))
 if ok and route in ["/auth/login","/auth/register"]:_auth_group.hide()
 if ok and route in ["/friends","/invites"]: listing.text=JSON.stringify(data,"  ")

func _section(title: String) -> VBoxContainer:
 var body := VBoxContainer.new()
 body.visible=false
 _button(title,func(): body.visible=not body.visible)
 _column.add_child(body)
 return body
func _t(ar: String) -> String:
 if language=="ar": return ar
 return str({
 "حسابي • Gaming Hub":"My account • Gaming Hub",
 "الحساب وتسجيل الدخول":"Account & sign in",
 "الاستمرار كضيف محلي":"Continue as local guest",
 "اسم اللاعب":"Player name",
 "البريد الإلكتروني":"Email",
 "كلمة المرور • 12 حرفًا على الأقل":"Password • at least 12 characters",
 "دخول حساب Gaming Hub":"Sign into Gaming Hub",
 "إنشاء حساب Gaming Hub":"Create Gaming Hub account",
 "جلسة ضيف على الخدمة المحلية":"Local service guest session",
 "الدخول عبر Google":"Continue with Google",
 "الدخول عبر Facebook":"Continue with Facebook",
 "تقدم الحساب وربطه":"Progress and account linking",
 "حفظ تقدمي في الحساب":"Save progress to account",
 "استعادة تقدم الحساب":"Restore account progress",
 "ربط جلسة الضيف السابقة بالحساب الحالي":"Link previous guest session to this account",
 "الأصدقاء والدعوات":"Friends and invitations",
 "معرف الصديق • يظهر معرفك بعد تسجيل الدخول":"Friend ID • your ID appears after sign-in",
 "إرسال طلب صداقة":"Send friend request",
 "قبول طلب هذا الصديق":"Accept this friend request",
 "عرض الأصدقاء والطلبات":"Show friends and requests",
 "كود الغرفة الحالي لدعوة الصديق":"Current room code for invitation",
 "دعوة الصديق للغرفة":"Invite friend to room",
 "نسخ كود دعوة الغرفة":"Copy room invitation code",
 "عرض الدعوات الواردة":"Show incoming invitations",
 "لوحة الإدارة • وصول مخول":"Admin dashboard • authorized access",
 "تسجيل خروج الحساب":"Sign out",
 "العودة":"Back"
 }.get(ar,ar))
