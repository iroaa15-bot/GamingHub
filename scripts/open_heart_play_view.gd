extends VBoxContainer
## Presentation only. The existing room client and voice adapter own all state.
var room: Control
var title: Label
var connection: Label
var instruction: Label
var prompt: Label
var detail: Label
var response: Label
var card: PanelContainer
var lobby: VBoxContainer
var content: VBoxContainer
var scroll: ScrollContainer
var actions: HBoxContainer
var participate: Button
var skip: Button
var next_round: Button
var dock: VBoxContainer
var ranking: VBoxContainer
var rows: Array[Label] = []
var phase_key := ""
var pending_key := ""
var pending_since := 0
var pending_kind := ""
var latest: Dictionary = {}
var transition: Tween
var backdrop: ColorRect
var tools: VBoxContainer
var tools_open := false
var resumed := false

func words(ar: String, en: String) -> String:
 return room.tr_pair(ar,en)

func text_node(parent: Node, size_value: int) -> Label:
 var node := Label.new()
 node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE
 node.add_theme_font_size_override("font_size",size_value)
 node.add_theme_color_override("font_color",Color("edf2ff"))
 parent.add_child(node)
 return node

func surface(color: Color) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color=color
 style.set_corner_radius_all(20)
 for edge in ["left","right","top","bottom"]:style.set("content_margin_"+edge,16)
 return style

func action_button(caption: String, callback: Callable, primary: bool=false) -> Button:
 var node := Button.new()
 node.text=caption
 node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 node.custom_minimum_size=Vector2(0,56)
 node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 node.add_theme_font_size_override("font_size",18)
 node.add_theme_stylebox_override("normal",surface(Color("326be8") if primary else Color("27334c")))
 node.add_theme_stylebox_override("pressed",surface(Color("244bb0") if primary else Color("35445f")))
 node.add_theme_stylebox_override("hover",node.get_theme_stylebox("normal"))
 node.add_theme_stylebox_override("focus",surface(Color("466ba6")))
 node.add_theme_stylebox_override("disabled",surface(Color("263145")))
 node.add_theme_color_override("font_color",Color.WHITE)
 node.add_theme_color_override("font_disabled_color",Color("a7b5cc"))
 node.pressed.connect(callback)
 return node

func setup(owner_room: Control) -> void:
 room=owner_room
 name="OpenHeartPlayView"
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 offset_left=16;offset_right=-16;offset_top=12;offset_bottom=-12
 add_theme_constant_override("separation",8)
 backdrop=ColorRect.new()
 backdrop.color=Color("111a2c")
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
 room.add_child(backdrop)
 room.move_child(backdrop,get_index())
 title=text_node(self,23)
 connection=text_node(self,14)
 scroll=ScrollContainer.new()
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus=true
 add_child(scroll)
 content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation",12);scroll.add_child(content)
 lobby=VBoxContainer.new();lobby.add_theme_constant_override("separation",8);content.add_child(lobby)
 var invite_row := HBoxContainer.new();lobby.add_child(invite_row)
 var copy := action_button(words("نسخ الكود","Copy code"),func():room._copy_room_code())
 var share := action_button(words("مشاركة","Share"),func():room._share_room_code())
 invite_row.add_child(copy);invite_row.add_child(share)
 instruction=text_node(content,21)
 card=PanelContainer.new();card.name="SocialPromptCard";card.custom_minimum_size.y=190
 card.add_theme_stylebox_override("panel",surface(Color("edf2fc")));content.add_child(card)
 prompt=text_node(card,27);prompt.add_theme_color_override("font_color",Color("15233d"))
 prompt.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 detail=text_node(content,15)
 ranking=VBoxContainer.new();content.add_child(ranking)
 for i in range(6):rows.append(text_node(ranking,20))
 var tools_button := action_button(words("الدردشة والإبلاغ","Chat & report"),func():tools_open=not tools_open;tools.visible=tools_open)
 tools_button.custom_minimum_size.y=44;content.add_child(tools_button)
 tools=VBoxContainer.new();tools.hide();content.add_child(tools)
 room._social_chat.reparent(tools)
 for node in [room.target_player,room.report_reason,room.report_button,room.block_button]:node.reparent(tools)
 response=text_node(self,15)
 actions=HBoxContainer.new();actions.add_theme_constant_override("separation",8);add_child(actions)
 participate=action_button(words("شاركت · +10","Participated · +10"),func():submit("finish",true),true)
 skip=action_button(words("تخطي","Skip"),func():submit("finish",false))
 next_round=action_button(words("الجولة التالية","Next round"),func():submit("next"),true)
 for node in [participate,skip,next_round]:actions.add_child(node)
 for node in [room.voice_button,room.voice_mute_button,room._accept_button]:
  for state_name in ["normal","pressed","hover","focus","disabled"]:
   node.add_theme_stylebox_override(state_name,participate.get_theme_stylebox(state_name))
 dock=VBoxContainer.new();dock.add_theme_constant_override("separation",4);add_child(dock)
 var leave := action_button(words("مغادرة الغرفة","Leave room"),func():room.confirm_party_leave())
 leave.custom_minimum_size.y=44;add_child(leave)
 set_process(true)
 hide();backdrop.hide()

func restore_shared_layout() -> void:
 # The legacy renderer expects these nodes under its column while updating.
 if room._seats.get_parent()!=room._main_column:room._seats.reparent(room._main_column)
 if room._agreement_box.get_parent()!=room._main_column:room._agreement_box.reparent(room._main_column)

func display(value: Dictionary) -> void:
 latest=value.duplicate(true)
 var party: Dictionary=value.get("party",{})
 var phase: String=str(party.get("phase","lobby"))
 var in_room: bool=not room.client.code.is_empty() and not bool(value.get("closed",false))
 visible=in_room
 backdrop.visible=in_room
 room._main_column.visible=not in_room
 room.party_panel.hide()
 if not in_room:
  pending_key="";phase_key=""
  if room._voice_controls.get_parent()!=room._main_column:room._voice_controls.reparent(room._main_column)
  return
 room._seats.reparent(content)
 content.move_child(room._seats,0)
 room._seats.show()
 room._seats.columns=2 if int(value.get("capacity",2))<=2 else 3
 for i in range(6):
  room._seat_avatars[i].custom_minimum_size=Vector2(36,36)
  room._seat_labels[i].add_theme_font_size_override("font_size",14)
  room._seat_statuses[i].add_theme_font_size_override("font_size",12)
  room._seat_panels[i].add_theme_stylebox_override("panel",surface(Color("213553") if i==int(party.get("actor",-1)) and phase=="active" else Color("1b273c")))
 room._agreement_box.reparent(lobby)
 room._voice_controls.reparent(dock)
 room._voice_controls.visible=bool(value.get("room_agreement",false)) and str(value.get("primary_mode","voice")) in ["voice","mixed"] and bool(room.client.capabilities.get("voice",false))
 room.voice_status.add_theme_font_size_override("font_size",12)
 room.voice_status.custom_minimum_size.y=40
 room.voice_status.max_lines_visible=2
 room._voice_changed()
 room.clock.hide();room._clock_bar.hide()
 room._social_chat.visible=phase!="lobby" and str(value.get("primary_mode","voice")) in ["text","mixed"]
 room._chat_toggle.visible=room._social_chat.visible
 tools.visible=tools_open
 var connected: bool=not room.client.capabilities.is_empty()
 var paused: bool=bool(value.get("paused",false)) or not connected
 if resumed and not paused:
  pending_key=""
  resumed=false
 connection.text=words("جار استعادة الاتصال · إجابتك لا تُعاد تلقائيًا","Reconnecting · answers are not resent automatically") if paused else words("متصل · الصوت اختياري","Connected · voice is optional")
 connection.add_theme_color_override("font_color",Color("ffd58c") if paused else Color("9db2ce"))
 lobby.visible=phase=="lobby"
 room._agreement_box.visible=lobby.visible and bool(value.get("room_agreement",false))
 var count: int=int(value.get("capacity",2))
 var ready_count: int=value.get("confirmed",[]).count(true)
 room._agreement_info.text=words("الجاهزون %d/%d · %d جولات","Ready %d/%d · %d rounds") % [ready_count,count,int(party.get("rounds",10))]
 title.text=words("افتح قلبك · الغرفة %s","Open Heart · Room %s") % room.client.code if phase=="lobby" else words("افتح قلبك · الجولة %d/%d","Open Heart · Round %d/%d") % [mini(int(party.get("round",0))+(1 if phase=="active" else 0),int(party.get("rounds",10))),int(party.get("rounds",10))]
 card.visible=phase=="active"
 var actor: int=int(party.get("actor",-1))
 var own_turn: bool=actor==room.client.player
 instruction.text=words("دورك · شارك بالقدر الذي يريحك","Your turn · share as much as you feel comfortable") if own_turn else words("استمع إلى %s","Listen to %s") % room._social_player_name(actor)
 var prompt_data: Dictionary=party.get("card",{}) if party.get("card") is Dictionary else {}
 prompt.text=str(prompt_data.get("text_ar","")) if room.language=="ar" else str(prompt_data.get("text_en",prompt_data.get("text_ar","")))
 detail.text=words("بدون مؤقت · يمكنك التخطي دون خصم","No timer · skip without a penalty")
 if room.language=="en" and not prompt_data.has("text_en") and phase=="active":detail.text="This card is in Arabic. No timer · skip without a penalty."
 participate.visible=phase=="active" and own_turn
 skip.visible=participate.visible
 next_round.visible=phase=="results" and room.client.player==0
 ranking.visible=phase in ["results","finished"]
 if phase=="lobby":
  instruction.text=words("اجمع أصحابك ثم استعدوا للعب","Gather your friends and get ready")
  detail.text=words("المشاركة = 10 نقاط · التخطي بدون خصم","Participation = 10 points · skipping has no penalty")
 elif ranking.visible:
  instruction.text=words("نتيجة الجولة","Round result") if phase=="results" else words("انتهت المباراة","Match complete")
  if phase=="finished":
   var winner: int=int(value.get("winner",-1))
   instruction.text=words("انتهت المباراة بالتعادل","Match finished in a draw") if winner<0 else words("الفائز: %s","Winner: %s") % room._social_player_name(winner)
   room.status.text=instruction.text
  detail.text=words("مجموع نقاط المباراة · المكالمة متاحة حتى المغادرة","Match points · voice remains available until you leave")
  var awards: Dictionary=party.get("result",{}).get("awards",{})
  if phase=="results":
   var awarded: Array=awards.keys()
   detail.text=words("تم تخطي الكارت · بدون نقاط","Card skipped · no points awarded") if awarded.is_empty() else words("%s حصل على +%d نقطة","%s earned +%d points") % [room._social_player_name(int(awarded[0])),int(awards[awarded[0]])]
  var scores: Array=value.get("scores",[])
  var order: Array=range(scores.size())
  order.sort_custom(func(a,b):return int(scores[a])>int(scores[b]))
  for i in range(rows.size()):
   rows[i].visible=i<order.size()
   if i<order.size():rows[i].text=words("%s · %d نقطة","%s · %d points") % [room._social_player_name(order[i]),int(scores[order[i]])]
 var next_key: String=room.client.code+":"+phase+":"+str(party.get("round",0))+":"+str(party.get("card_id",""))
 if next_key!=phase_key:
  phase_key=next_key;pending_key="";response.text=""
  scroll.scroll_vertical=0
  if transition and transition.is_valid():transition.kill()
  card.modulate.a=1.0
  if not bool(room.get_tree().root.get_meta("reduced_motion",false)) and card.visible:
   card.modulate.a=0.4;transition=create_tween();transition.tween_property(card,"modulate:a",1.0,0.18)
 if paused:response.text=words("المباراة متوقفة حتى عودة الاتصال","Play is paused until connection returns")
 elif pending_key.is_empty():response.text=words("بانتظار صاحب الغرفة للجولة التالية","Waiting for the host to continue") if phase=="results" and room.client.player!=0 else (words("بانتظار مشاركة اللاعب","Waiting for the player to share") if phase=="active" and not own_turn else "")
 for node in [participate,skip,next_round]:node.disabled=paused or not pending_key.is_empty()

func submit(kind: String, participated: bool=false) -> void:
 if not pending_key.is_empty() or bool(latest.get("paused",false)) or room.client.capabilities.is_empty():return
 var party: Dictionary=latest.get("party",{})
 var phase: String=str(party.get("phase",""))
 if kind=="finish" and (phase!="active" or str(party.get("actor",""))!=str(room.client.player)):return
 if kind=="next" and (phase!="results" or room.client.player!=0):return
 var result: int
 if kind=="next":result=room.client.send_action("duel_party_next",{"round":int(party.get("round",0))})
 else:result=room.client.send_action("duel_party_finish",{"card_id":str(party.get("card_id","")),"participated":participated})
 if result!=OK:
  response.text=words("تعذر الإرسال · حاول مجددًا","Could not send · try again")
  return
 pending_key=phase_key;pending_kind=kind;pending_since=Time.get_ticks_msec()
 response.text=words("جار تسجيل المشاركة…","Recording your response…") if kind=="finish" else words("جار بدء الجولة…","Starting the round…")
 for node in [participate,skip,next_round]:node.disabled=true

func rejected(message: Dictionary) -> void:
 if message.get("type")=="duel_resumed":
  resumed=true
  return
 if message.get("type")!="duel_error" or message.get("scope")=="voice" or pending_key.is_empty():return
 # A rejected action may be retried explicitly; never replay it on reconnect.
 pending_key=""
 display(latest)
 response.text=words("لم تُسجل العملية · راجع الاتصال وحاول مجددًا","Action was not recorded · check connection and try again")

func _process(_delta: float) -> void:
 if pending_key.is_empty():return
 if Time.get_ticks_msec()-pending_since>8000:
  # Keep the lock until a canonical state changes or a rejection arrives.
  response.text=words("بانتظار تأكيد الغرفة · لا حاجة للضغط مجددًا","Waiting for room confirmation · no need to tap again")
