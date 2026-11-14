extends VBoxContainer
signal back_requested
const MenuSkin=preload("res://scripts/visual_skin.gd")
var language := "ar"
var client: Node
var balance_label: Label
var details: Label
var _hint_buttons: Dictionary={}
var prices={"reward":20,"hint":20,"letter":30,"remove_two":40,"replace_image":60}
func tr_pair(ar: String,en: String) -> String:return ar if language=="ar" else en
func _ready() -> void:
 add_theme_constant_override("separation",12)
 MenuSkin.compact_header(self,tr_pair("المساعدات والعملات","Hints & coins"))
 balance_label=Label.new();balance_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 balance_label.text=tr_pair("الرصيد الموثق غير متاح • الخدمة غير مفعلة","Verified balance unavailable • service not activated")
 add_child(balance_label)
 for item in [["hint","تلميح صغير","Small hint"],["letter","كشف حرف","Reveal a letter"],["remove_two","استبعاد إجابتين خطأ","Remove two wrong choices"],["replace_image","تغيير الصورة","Replace picture"]]:
  var button:=Button.new();button.text=tr_pair(item[1],item[2])+" • "+str(prices[item[0]])
  button.custom_minimum_size.y=64;button.disabled=true
  button.tooltip_text=tr_pair("يتطلب رصيدًا موثقًا وتحقق الخادم من صلاحية المساعدة في الجولة","Requires verified balance and server authorization for this round")
  button.set_meta("label",tr_pair(item[1],item[2]));_hint_buttons[item[0]]=button
  MenuSkin.decorate_button(button,"amber" if item[0]=="hint" else "secondary");add_child(button)
 var ad:=Button.new();ad.text=tr_pair("إعلان اختياري • 20 عملة بعد التحقق","Optional ad • 20 coins after verification")
 ad.disabled=true;ad.custom_minimum_size.y=60;MenuSkin.decorate_button(ad,"violet");add_child(ad)
 details=Label.new();details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 details.text=tr_pair("الإعلانات والمساعدات غير مفعلة حتى ربط التحقق من المكافأة بالخادم. اللعب العادي مجاني. لا تُضاف عملات من ضغط الزر أو إغلاق الإعلان.","Ads and hints remain unavailable until server reward verification is connected. Normal play is free. Button presses and ad closure never grant coins.")
 add_child(details)
 var back:=Button.new();back.text=tr_pair("العودة","Back");back.custom_minimum_size.y=56;MenuSkin.decorate_button(back,"gold");back.pressed.connect(func():back_requested.emit.call_deferred());add_child(back)
 client=get_tree().root.get_node_or_null("PlayerAccountSession")
 if is_instance_valid(client) and not client.token.is_empty():
  client.changed.connect(_wallet_result)
  client.request("/wallet",{},false)
func _wallet_result(route: String,data: Dictionary,ok: bool) -> void:
 if route!="/wallet":return
 if ok:
  for key in _hint_buttons:
   var price: int=int(data.get("prices",{}).get(key,prices[key]))
   _hint_buttons[key].text=str(_hint_buttons[key].get_meta("label"))+" • "+str(price)
  balance_label.text=tr_pair("الرصيد الموثق: %d عملة","Verified balance: %d coins") % int(data.get("balance",0))
  details.text=tr_pair("الرصيد مصدره دفتر الخادم فقط. الإنفاق والمكافآت معلقان حتى اكتمال التحقق والربط بالمباراة.","Balance comes only from the server ledger. Spending and rewards await verification and game integration.")

