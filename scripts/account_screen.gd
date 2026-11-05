extends Control
## Player sign-in only. Endpoints are configured by the build, never by this UI.
const AccountSkin=preload("res://scripts/visual_skin.gd")
var auth: Node
var language := "ar"
var panel: VBoxContainer
var email_field: LineEdit
var password_field: LineEdit
var name_field: LineEdit
var status_label: Label
var submit_busy := false
var register_mode := false
var action_buttons: Array[Button]=[]
var provider_buttons: Dictionary={}

func _t(ar: String,en: String) -> String:
 return ar if language=="ar" else en

func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST and not submit_busy: _back()

func _ready() -> void:
 auth=get_node("/root/GamingHubAccount")
 language=load("res://scripts/player_preferences.gd").language()
 layout_direction=Control.LAYOUT_DIRECTION_RTL if language=="ar" else Control.LAYOUT_DIRECTION_LTR
 register_mode=auth.requested_action=="register"
 var background=AccountSkin.new()
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(background)
 var scroll:=ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.offset_left=18;scroll.offset_right=-18;scroll.offset_top=28;scroll.offset_bottom=-28
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus=true;scroll.scroll_deadzone=14
 add_child(scroll)
 var guard=load("res://scripts/menu_touch_guard.gd").new()
 guard.scroll_area=scroll;scroll.add_child(guard)
 panel=VBoxContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 panel.add_theme_constant_override("separation",12);scroll.add_child(panel)
 AccountSkin.compact_header(panel,_t("حساب Gaming Hub","Gaming Hub account"))
 _text(_t("تقدمك محفوظ. التسجيل اختياري ويمكنك متابعة اللعب كضيف.","Your progress is safe. Sign-in is optional; guest play remains available."))
 if not auth.user_profile.is_empty():
  _text(str(auth.user_profile.get("display_name",_t("اللاعب","Player"))))
 name_field=_field(_t("اسم اللاعب","Player name"))
 name_field.visible=register_mode
 email_field=_field(_t("البريد الإلكتروني","Email"))
 email_field.layout_direction=Control.LAYOUT_DIRECTION_LTR
 email_field.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
 password_field=_field(_t("كلمة المرور • 12 حرفًا على الأقل","Password • at least 12 characters"))
 password_field.secret=true
 password_field.layout_direction=Control.LAYOUT_DIRECTION_LTR
 password_field.max_length=256
 _button(_t("إنشاء حساب","Create account") if register_mode else _t("تسجيل الدخول","Sign in"),_email_action,"gold")
 _button(_t("لديك حساب؟ تسجيل الدخول","Already registered? Sign in") if register_mode else _t("إنشاء حساب جديد","Create a new account"),_switch_mode)
 for provider in ["google","facebook"]:
  var name_value: String="Google" if provider=="google" else "Facebook"
  var connected: bool=provider in auth.user_profile.get("providers",[])
  var title_value: String=name_value+_t(" مرتبط"," linked") if connected else (_t("ربط ","Link ") if not auth.user_profile.is_empty() else _t("المتابعة باستخدام ","Continue with "))+name_value
  var control: Button=_button(title_value,_provider_action.bind(provider))
  control.disabled=true;provider_buttons[provider]=control
 status_label=_text("")
 _button(_t("استعادة الحساب والتقدم","Restore account and progress"),_restore)
 _button(_t("المتابعة كضيف","Continue as guest"),_back,"teal")
 AccountSkin.compact_menu(panel)
 AccountSkin.enable_menu_swipe(panel)
 _check_providers.call_deferred()

func _field(placeholder: String) -> LineEdit:
 var field:=LineEdit.new();field.placeholder_text=placeholder;field.max_length=254
 AccountSkin.decorate_input(field);field.custom_minimum_size.y=54;panel.add_child(field)
 return field

func _text(value: String) -> Label:
 var text:=Label.new();text.text=value;text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;panel.add_child(text)
 return text

func _button(title: String,action: Callable,tone: String="secondary") -> Button:
 var control:=Button.new();control.text=title;control.custom_minimum_size.y=54
 control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;AccountSkin.decorate_button(control,tone)
 control.pressed.connect(func():
  if not submit_busy: action.call(),CONNECT_DEFERRED)
 action_buttons.append(control);panel.add_child(control)
 return control

func _local_progress() -> Dictionary:
 var value: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://progress_v10_all.json")) if FileAccess.file_exists("user://progress_v10_all.json") else {}
 return value if value is Dictionary else {}

func _check_providers() -> void:
 var result: Dictionary=await auth._call("/auth/providers",HTTPClient.METHOD_GET)
 if not is_inside_tree(): return
 var native: bool=auth.secure_store!=null and auth.secure_store.has_signal("social_result")
 for provider in provider_buttons:
  provider_buttons[provider].set_meta("provider_available",native and result.get("ok",false) and result.get("data",{}).get(provider,false))
  provider_buttons[provider].disabled=not provider_buttons[provider].get_meta("provider_available") or provider in auth.user_profile.get("providers",[])
 var requested: String=auth.requested_provider
 auth.requested_provider=""
 if not requested.is_empty(): _provider_action(requested)

func _switch_mode() -> void:
 auth.requested_action="login" if register_mode else "register"
 get_tree().reload_current_scene()

func _busy(value: bool) -> void:
 submit_busy=value
 for control in action_buttons: control.disabled=value
 for provider in provider_buttons:
  provider_buttons[provider].disabled=value or not provider_buttons[provider].get_meta("provider_available",false) or provider in auth.user_profile.get("providers",[])
 email_field.editable=not value;password_field.editable=not value;name_field.editable=not value
 if value: status_label.text=_t("جارٍ الاتصال…","Connecting…")

func _email_action() -> void:
 if email_field.text.strip_edges().is_empty() or password_field.text.length()<12 or (register_mode and name_field.text.strip_edges().is_empty()):
  status_label.text=_t("أدخل البريد وكلمة مرور من 12 حرفًا على الأقل، والاسم عند إنشاء حساب.","Enter your email, a password of at least 12 characters, and a name for a new account.")
  return
 _busy(true)
 var result: Dictionary
 if register_mode:
  result=await auth.upgrade_guest(email_field.text.strip_edges(),password_field.text,name_field.text.strip_edges()) if auth.user_profile.get("is_guest",false) else await auth.register_account(email_field.text.strip_edges(),password_field.text,name_field.text.strip_edges())
 else: result=await auth.login(email_field.text.strip_edges(),password_field.text)
 password_field.clear()
 await _finish(result)

func _provider_action(provider: String) -> void:
 if submit_busy: return
 _busy(true)
 var result: Dictionary=await auth.sign_in_provider(provider)
 await _finish(result)

func _finish(result: Dictionary) -> void:
 if not is_inside_tree(): return
 if result.get("ok",false):
  auth.complete_player_sign_in.call_deferred(_local_progress())
  auth.enter_home_once=true
  get_tree().change_scene_to_file("res://scenes/Main.tscn")
  return
 else: status_label.text=_safe_error(result)
 _busy(false)

func _restore() -> void:
 if auth.access_token.is_empty() and auth.refresh_token.is_empty():
  status_label.text=_t("سجّل الدخول بالطريقة التي ربطت بها حسابك لاستعادة تقدمك.","Sign in with the method linked to your account to restore progress.")
  return
 _busy(true)
 var result: Dictionary=await _restore_progress()
 if not is_inside_tree(): return
 status_label.text=_t("استُعيد الحساب والتقدم.","Account and progress restored.") if result.get("ok",false) else _safe_error(result)
 _busy(false)

func _restore_progress() -> Dictionary:
 var result: Dictionary=await auth.profile()
 if result.get("ok",false):
  var local: Dictionary=_local_progress()
  var saved: Dictionary=result.get("data",{}).get("user",{}).get("local_progress",{})
  for key in ["xp","wins","matches","picture_wins"]: local[key]=maxi(int(local.get(key,0)),int(saved.get(key,0)))
  var file:=FileAccess.open("user://progress_v10_all.json",FileAccess.WRITE)
  if file==null: return {"ok":false,"status":0}
  file.store_string(JSON.stringify(local));file.close()
 return result

func _safe_error(result: Dictionary) -> String:
 match int(result.get("status",0)):
  401: return _t("راجع البريد وكلمة المرور، ثم حاول مجددًا.","Check your email and password, then try again.")
  409: return _t("الحساب مرتبط بالفعل. سجّل الدخول إليه أولًا؛ تقدمك محفوظ.","This account is already linked. Sign in to it first; your progress is safe.")
  429: return _t("انتظر قليلًا قبل إعادة المحاولة.","Please wait before trying again.")
 return _t("تعذر تسجيل الدخول الآن. يمكنك المحاولة مجددًا أو اللعب كضيف.","Sign-in is unavailable right now. Try again or continue as a guest.")

func _back() -> void:
 if not submit_busy:
  auth.enter_home_once=true
  get_tree().change_scene_to_file("res://scenes/Main.tscn")
