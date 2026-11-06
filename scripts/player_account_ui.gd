extends VBoxContainer
signal back_requested
signal progress_received(value: Dictionary)
const MenuSkin=preload("res://scripts/visual_skin.gd")
var local_progress: Dictionary={}
var language := "ar"
var client: Node
var online_account: Node
var status: Label
var _profile_name: Label
var _server_points: Label
var _level: Label
var _stats: Label
var _xp_bar: ProgressBar
var _avatar: TextureRect
var _avatar_url := ""
var _snapshot_sent := false
var _busy := false
var _saving := false
var _friends_list: Label
var room_code: LineEdit
var show_friends_first := false

func _t(ar: String,en: String) -> String:
 return ar if language=="ar" else en

func _ready() -> void:
 layout_direction=Control.LAYOUT_DIRECTION_RTL if language=="ar" else Control.LAYOUT_DIRECTION_LTR
 add_theme_constant_override("separation",10)
 client=get_tree().root.get_node_or_null("PlayerAccountSession")
 if client==null:
  client=load("res://scripts/player_account_client.gd").new();client.name="PlayerAccountSession";get_tree().root.add_child(client)
 client.changed.connect(_result)
 online_account=get_tree().root.get_node_or_null("GamingHubAccount")
 MenuSkin.compact_header(self,_t("الأصدقاء","Friends") if show_friends_first else _t("حسابي","My profile"))
 var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",MenuSkin.card(Color("0b1649"),18));add_child(card)
 card.visible=not show_friends_first
 var content:=VBoxContainer.new();content.add_theme_constant_override("separation",8);card.add_child(content)
 _avatar=TextureRect.new();_avatar.texture=MenuSkin.menu_icon("player");_avatar.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_avatar.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_avatar.custom_minimum_size=Vector2(64,64);content.add_child(_avatar)
 _profile_name=Label.new();_profile_name.text=_t("ضيف","Guest");_profile_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_profile_name.add_theme_font_size_override("font_size",24);content.add_child(_profile_name)
 _level=Label.new();content.add_child(_level)
 _server_points=Label.new();_server_points.visible=false;content.add_child(_server_points)
 _xp_bar=ProgressBar.new();_xp_bar.show_percentage=false;_xp_bar.custom_minimum_size.y=12;content.add_child(_xp_bar)
 _stats=Label.new();content.add_child(_stats)
 _refresh_stats()
 status=_label(_t("تقدمك محفوظ على هذا الجهاز. ربط الحساب اختياري.","Your progress is saved on this device. Linking an account is optional."))
 _button(_t("إعدادات الحساب وربطه","Account settings and linking"),_open_account,"gold").visible=not show_friends_first
 _button(_t("تغيير الصورة الشخصية من المعرض","Change profile photo from gallery"),_choose_avatar).visible=not show_friends_first
 _button(_t("حفظ تقدمي في الحساب","Back up progress"),_save_online_progress).visible=not show_friends_first
 _button(_t("استعادة تقدم الحساب","Restore account progress"),_restore_online_progress).visible=not show_friends_first
 var friends:=VBoxContainer.new();friends.visible=show_friends_first
 _button(_t("الأصدقاء ودعوات اللعب","Friends and invitations"),func():friends.visible=not friends.visible).visible=not show_friends_first
 add_child(friends)
 _friends_list=Label.new();_friends_list.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;friends.add_child(_friends_list)
 var available: bool=not client.endpoint.is_empty() and not client.token.is_empty()
 _friends_list.text=_t("الأصدقاء متاحون عند الاتصال بخدمة الأصدقاء. يمكنك مشاركة كود غرفتك الآن.","Friends are available when the friend service is connected. You can share your room code now.") if not available else ""
 room_code=LineEdit.new();room_code.placeholder_text=_t("كود الغرفة","Room code");room_code.max_length=6;room_code.layout_direction=Control.LAYOUT_DIRECTION_LTR;MenuSkin.decorate_input(room_code);friends.add_child(room_code)
 var copy:=Button.new();copy.text=_t("نسخ كود الدعوة","Copy invitation code");MenuSkin.decorate_button(copy);copy.pressed.connect(_copy_invite);friends.add_child(copy)
 if online_account!=null and online_account.secure_store!=null and online_account.secure_store.has_signal("social_result"):
  var share:=Button.new();share.text=_t("مشاركة الدعوة عبر التطبيقات","Share invitation with apps");MenuSkin.decorate_button(share);share.pressed.connect(_share_invite);friends.add_child(share)
 if available:
  var refresh:=Button.new();refresh.text=_t("عرض الأصدقاء والدعوات","Show friends and invitations");MenuSkin.decorate_button(refresh);refresh.pressed.connect(func():client.request("/friends",{},false));friends.add_child(refresh)
 _button(_t("تسجيل الخروج","Sign out"),_logout_account,"danger").visible=not show_friends_first
 _button(_t("العودة للعبة","Back to game"),func():back_requested.emit.call_deferred(),"teal")
 MenuSkin.compact_menu(self)
 if show_friends_first:status.text=_t("شارك كود الغرفة مع صديقك للعب معًا.","Share your room code with a friend to play together.")
 if online_account!=null:
  online_account.profile_changed.connect(_online_profile)
  online_account.avatar_finished.connect(_avatar_finished)
  _online_profile(online_account.user_profile)
  if not online_account.access_token.is_empty(): online_account.profile.call_deferred()

func _label(text: String) -> Label:
 var control:=Label.new();control.text=text;control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(control);return control

func _button(title: String,action: Callable,tone: String="secondary") -> Button:
 var control:=Button.new();control.text=title;control.custom_minimum_size.y=52;control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 MenuSkin.decorate_button(control,tone);control.pressed.connect(func():
  if not _busy: action.call(),CONNECT_DEFERRED)
 add_child(control);return control

func _open_account() -> void:
 online_account.requested_action="login"
 get_tree().change_scene_to_file("res://scenes/AccountScreen.tscn")

func _refresh_stats() -> void:
 var xp: int=maxi(0,int(local_progress.get("xp",0)))
 _level.text=_t("المستوى %d • تقدم %d XP","Level %d • %d XP progress") % [1+floori(xp/100.0),xp]
 _xp_bar.value=xp%100
 _stats.text=_t("%d انتصارات • %d مباريات","%d wins • %d matches") % [int(local_progress.get("wins",0)),int(local_progress.get("matches",0))]

func _online_profile(user: Dictionary) -> void:
 if not is_inside_tree(): return
 _server_points.visible=not user.is_empty()
 if user.is_empty():
  _profile_name.text=_t("ضيف","Guest");_avatar_url="";_avatar.texture=MenuSkin.menu_icon("player");return
 _profile_name.text=str(user.get("display_name",_t("اللاعب","Player")))
 _server_points.text=_t("نقاط الحساب: %d","Account points: %d") % int(user.get("points",0))
 var providers: Array=user.get("providers",[])
 if not providers.is_empty(): _server_points.text+="\n"+" + ".join(PackedStringArray(providers))
 _load_avatar(str(user.get("avatar_url","")))
 if not _snapshot_sent and not online_account.access_token.is_empty():
  _snapshot_sent=true;_save_online_progress.call_deferred()

func _choose_avatar() -> void:
 if online_account==null or not online_account.choose_avatar():
  status.text=_t("سجّل الدخول لاختيار صورة لحسابك، أو انتظر اكتمال الطلب الحالي.","Sign in to choose an account photo, or wait for the current request.");return
 status.text=_t("اختر صورة ستظهر في ملفك وغرف اللعب.","Choose a photo to appear on your profile and in game rooms.")

func _avatar_finished(ok: bool,error: String) -> void:
 if error=="cancelled":status.text=_t("لم تتغير صورتك.","Your photo is unchanged.");return
 status.text=_t("حُفظت صورة حسابك.","Your account photo was saved.") if ok else _t("تعذر حفظ الصورة؛ صورتك السابقة محفوظة.","Photo could not be saved; your previous photo is safe.")

func _load_avatar(url: String) -> void:
 if url.begins_with("/api/avatars/") and online_account!=null:url=online_account.session_origin+url
 if url==_avatar_url or not url.begins_with("https://") or "@" in url: return
 _avatar_url=url
 var request:=HTTPRequest.new();request.timeout=8;request.body_size_limit=1048576;add_child(request)
 if request.request(url)!=OK:request.queue_free();return
 var response: Array=await request.request_completed
 request.queue_free()
 if not is_inside_tree() or _avatar_url!=url or response[0]!=HTTPRequest.RESULT_SUCCESS or response[1]!=200:return
 var image:=Image.new()
 var data: PackedByteArray=response[3]
 var error: Error=ERR_INVALID_DATA
 if data.size()>12:
  if data[0]==0x89:error=image.load_png_from_buffer(data)
  elif data[0]==0xff:error=image.load_jpg_from_buffer(data)
  elif data.slice(0,4).get_string_from_ascii()=="RIFF":error=image.load_webp_from_buffer(data)
 if error==OK and image.get_width()<=2048 and image.get_height()<=2048:_avatar.texture=ImageTexture.create_from_image(image)

func _save_online_progress() -> void:
 if _saving: return
 if online_account==null or online_account.access_token.is_empty():status.text=_t("سجّل الدخول لحفظ التقدم في حسابك.","Sign in to back up progress to your account.");return
 _saving=true
 var result: Dictionary=await online_account.sync_progress(local_progress)
 if not is_inside_tree(): return
 _saving=false
 status.text=_t("حُفظ تقدمك في الحساب.","Progress backed up.") if result.get("ok",false) else _t("تعذر الحفظ الآن؛ تقدم الجهاز محفوظ.","Backup is unavailable; device progress is safe.")

func _restore_online_progress() -> void:
 if online_account==null or (online_account.access_token.is_empty() and online_account.refresh_token.is_empty()):status.text=_t("سجّل الدخول لاستعادة حسابك.","Sign in to restore your account.");return
 _busy=true
 var response: Dictionary=await online_account.profile()
 if not is_inside_tree(): return
 _busy=false
 if not response.get("ok",false):status.text=_t("تعذر الاتصال؛ تقدم الجهاز محفوظ.","Connection unavailable; device progress is safe.");return
 var saved: Dictionary=response.get("data",{}).get("user",{}).get("local_progress",{})
 for key in ["xp","wins","matches","picture_wins"]:local_progress[key]=maxi(int(local_progress.get(key,0)),int(saved.get(key,0)))
 progress_received.emit(local_progress.duplicate())
 _refresh_stats()
 status.text=_t("استُعيد تقدم الحساب دون فقدان تقدم الجهاز.","Account progress restored without losing device progress.")

func _logout_account() -> void:
 _busy=true
 if online_account!=null:await online_account.logout()
 if not is_inside_tree(): return
 _busy=false
 if not client.token.is_empty():client.request("/auth/logout")
 status.text=_t("تم تسجيل الخروج. تقدم الجهاز محفوظ.","Signed out. Device progress is preserved.")

func _copy_invite() -> void:
 var value:=room_code.text.strip_edges()
 if value.length()!=6 or not value.is_valid_int():status.text=_t("أدخل كود الغرفة من ستة أرقام.","Enter the six-digit room code.");return
 DisplayServer.clipboard_set(value)
 status.text=_t("نُسخ الكود. يمكنك لصقه في WhatsApp أو أي تطبيق مشاركة.","Code copied. Paste it into WhatsApp or any sharing app.")

func _share_invite() -> void:
 var value:=room_code.text.strip_edges()
 if value.length()!=6 or not value.is_valid_int():status.text=_t("أدخل كود الغرفة من ستة أرقام.","Enter the six-digit room code.");return
 online_account.secure_store.call_deferred("shareRoomCode",value,language)

func _result(route: String,data: Dictionary,ok: bool) -> void:
 if not is_inside_tree(): return
 if route not in ["/friends","/invites"]: return
 if not ok:_friends_list.text=_t("الأصدقاء غير متاحين الآن؛ يمكنك مشاركة كود الغرفة.","Friends are unavailable; you can still share your room code.");return
 var names: PackedStringArray=[]
 for item in data.get("friends",[]):
  if item is Dictionary:names.append(str(item.get("name",_t("لاعب","Player"))))
 _friends_list.text="\n".join(names) if not names.is_empty() else _t("لا توجد صداقات متاحة بعد.","No friends available yet.")
