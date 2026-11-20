extends VBoxContainer
## Shared social-game presentation. Room transport, secrets and scoring remain authoritative.
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
var actions: GridContainer
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
var option_buttons: Array[Button]=[]
var options: Array[Dictionary]=[]
var pending_action := ""
var timer_slot: VBoxContainer
var room_code: Label
var lobby_players: Label
var seat_columns: Array[VBoxContainer] = []
var seat_rows: Array[HBoxContainer] = []

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

func surface(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color=color
 style.set_corner_radius_all(20)
 if border.a > 0:
  style.border_color=border
  style.set_border_width_all(2)
 for edge in ["left","right","top","bottom"]:style.set("content_margin_"+edge,16)
 return style

func accent_button(node: Button, color: Color) -> void:
 var normal:=surface(color, color.lightened(0.4))
 normal.set_corner_radius_all(14)
 for edge in ["left","right","top","bottom"]:normal.set("content_margin_"+edge,6)
 var pressed:=normal.duplicate() as StyleBoxFlat
 pressed.bg_color=color.darkened(0.28)
 node.add_theme_stylebox_override("normal",normal)
 node.add_theme_stylebox_override("hover",normal)
 node.add_theme_stylebox_override("pressed",pressed)

func action_button(caption: String, callback: Callable, primary: bool=false) -> Button:
 var node := Button.new()
 node.text=caption
 node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 node.custom_minimum_size=Vector2(0,56)
 node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 node.add_theme_font_size_override("font_size",18)
 load("res://scripts/visual_skin.gd").decorate_play_action(node,"primary" if primary else "secondary")
 node.add_theme_color_override("font_color",Color.WHITE)
 node.add_theme_color_override("font_disabled_color",Color("a7b5cc"))
 node.pressed.connect(callback)
 return node

func setup(owner_room: Control) -> void:
 room=owner_room
 room._fixed_voice_labels=true
 name="SocialPlayView"
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 offset_left=16;offset_right=-16;offset_top=12;offset_bottom=-12
 add_theme_constant_override("separation",8)
 backdrop=ColorRect.new()
 backdrop.color=Color("07102e")
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
 room.add_child(backdrop)
 room.move_child(backdrop,get_index())
 var heading:=PanelContainer.new()
 heading.add_theme_stylebox_override("panel",surface(Color("101c4a"),Color("6679f2")))
 add_child(heading)
 title=text_node(heading,23)
 connection=text_node(self,14)
 timer_slot=VBoxContainer.new();add_child(timer_slot)
 scroll=ScrollContainer.new()
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus=true
 add_child(scroll)
 content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation",12);scroll.add_child(content)
 lobby=VBoxContainer.new();lobby.add_theme_constant_override("separation",8);content.add_child(lobby)
 var code_panel:=PanelContainer.new()
 var code_style:=surface(Color("061633"),Color("218be5"))
 code_style.set_corner_radius_all(14)
 for edge in ["top","bottom"]:code_style.set("content_margin_"+edge,5)
 code_panel.add_theme_stylebox_override("panel",code_style);lobby.add_child(code_panel)
 room_code=text_node(code_panel,22);room_code.add_theme_color_override("font_color",Color("ffdd45"))
 var invite_row := HBoxContainer.new();lobby.add_child(invite_row)
 var copy := action_button(words("نسخ الكود","Copy code"),func():room._copy_room_code())
 var share := action_button(words("مشاركة","Share"),func():room._share_room_code())
 invite_row.add_child(copy);invite_row.add_child(share)
 lobby_players=text_node(lobby,17)
 for panel in room._seat_panels:
  var original:=panel.get_child(0) as VBoxContainer
  seat_columns.append(original)
  var horizontal:=HBoxContainer.new()
  horizontal.add_theme_constant_override("separation",8)
  panel.add_child(horizontal);horizontal.hide();seat_rows.append(horizontal)
 instruction=text_node(content,21)
 card=PanelContainer.new();card.name="SocialPromptCard";card.custom_minimum_size.y=190
 card.add_theme_stylebox_override("panel",surface(Color("f3f3ff"),Color("ee428f")));content.add_child(card)
 prompt=text_node(card,27);prompt.add_theme_color_override("font_color",Color("15233d"))
 prompt.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 detail=text_node(content,15)
 ranking=VBoxContainer.new();content.add_child(ranking)
 for i in range(6):
  var row:=text_node(ranking,20)
  row.custom_minimum_size.y=42
  row.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
  row.add_theme_stylebox_override("normal",surface(Color("101e43"),Color("387ed4")))
  rows.append(row)
 var tools_button := action_button(words("الدردشة والإبلاغ","Chat & report"),func():tools_open=not tools_open;tools.visible=tools_open)
 tools_button.custom_minimum_size.y=44;content.add_child(tools_button)
 tools=VBoxContainer.new();tools.hide();content.add_child(tools)
 room._social_chat.reparent(tools)
 for node in [room.target_player,room.report_reason,room.report_button,room.block_button]:node.reparent(tools)
 response=text_node(self,15)
 actions=GridContainer.new();actions.columns=2;actions.add_theme_constant_override("h_separation",8);actions.add_theme_constant_override("v_separation",6);add_child(actions)
 participate=action_button("",func():submit_option(0),true)
 skip=action_button("",func():submit_option(1))
 next_round=action_button(words("الجولة التالية","Next round"),func():submit("next"),true)
 option_buttons.assign([participate,skip])
 for i in range(2,6):
  var index: int=i
  option_buttons.append(action_button("",func():submit_option(index)))
 for node in option_buttons:actions.add_child(node)
 actions.add_child(next_round)
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
 for node in [room.clock,room._clock_bar]:
  if node.get_parent()!=room._main_column:node.reparent(room._main_column)

func display(value: Dictionary) -> void:
 latest=value.duplicate(true)
 var party: Dictionary=value.get("party",{})
 var phase: String=str(party.get("phase","lobby"))
 var category: String=str(party.get("category",room.selected_social))
 # The two contrasting choices match the party-card reference. Other games
 # use neutral choices so a colour never suggests an unconfirmed answer.
 if category=="open_heart":
  accent_button(participate,Color("087c39"));accent_button(skip,Color("a01e43"))
 else:
  load("res://scripts/visual_skin.gd").decorate_play_action(participate,"primary")
  load("res://scripts/visual_skin.gd").decorate_play_action(skip,"secondary")
 var in_room: bool=not room.client.code.is_empty() and not bool(value.get("closed",false))
 visible=in_room
 backdrop.visible=in_room
 room._main_column.visible=not in_room
 room.party_panel.hide()
 if not in_room:
  pending_key="";phase_key=""
  if room._voice_controls.get_parent()!=room._main_column:room._voice_controls.reparent(room._main_column)
  return
 if phase=="lobby":
  if room._seats.get_parent()!=lobby:room._seats.reparent(lobby)
  lobby.move_child(room._seats,3)
 else:
  if room._seats.get_parent()!=content:room._seats.reparent(content)
  content.move_child(room._seats,0)
 room._seats.show()
 room._seats.columns=1 if phase=="lobby" else (2 if int(value.get("capacity",2))<=2 else 3)
 for i in range(6):
  var compact: bool=phase!="lobby"
  var destination: BoxContainer=seat_columns[i] if compact else seat_rows[i]
  for seat_node in [room._seat_avatars[i],room._seat_labels[i],room._seat_statuses[i]]:
   if seat_node.get_parent()!=destination:seat_node.reparent(destination)
  seat_columns[i].visible=compact;seat_rows[i].visible=not compact
  room._seat_panels[i].custom_minimum_size.y=76 if compact else 42
  room._seat_avatars[i].custom_minimum_size=Vector2(24,24)
  room._seat_labels[i].size_flags_horizontal=Control.SIZE_EXPAND_FILL
  room._seat_statuses[i].size_flags_horizontal=Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_CENTER
  room._seat_statuses[i].custom_minimum_size.x=0 if compact else 110
  room._seat_statuses[i].autowrap_mode=TextServer.AUTOWRAP_WORD_SMART if compact else TextServer.AUTOWRAP_OFF
  room._seat_statuses[i].clip_text=not compact
  room._seat_statuses[i].max_lines_visible=-1 if compact else 1
  room._seat_labels[i].add_theme_font_size_override("font_size",14)
  room._seat_statuses[i].add_theme_font_size_override("font_size",12)
  var is_actor: bool=i==int(party.get("actor",-1)) and phase=="active"
  var player_style: StyleBoxFlat=surface(Color("142e57") if is_actor else Color("101e40"),Color("ffd459") if is_actor else Color("3080ca"))
  for edge in ["top","bottom","left","right"]:player_style.set("content_margin_"+edge,6)
  if compact:
   room._seat_labels[i].text=room._social_player_name(i).left(14)+" · "+str(int(value.get("scores",[])[i]) if i<value.get("scores",[]).size() else 0)
   if i<value.get("connected",[]).size() and not bool(value.connected[i]):room._seat_labels[i].text+=" ↻"
  room._seat_statuses[i].visible=not compact
  room._seat_panels[i].add_theme_stylebox_override("panel",player_style)
 room._agreement_box.reparent(lobby)
 room._voice_controls.reparent(dock)
 room._voice_controls.visible=bool(value.get("room_agreement",false)) and str(value.get("primary_mode","voice")) in ["voice","mixed"] and bool(room.client.capabilities.get("voice",false))
 room.voice_status.add_theme_font_size_override("font_size",12)
 room.voice_status.custom_minimum_size.y=40
 room.voice_status.max_lines_visible=2
 room._voice_changed()
 room.voice_button.text=words("إنهاء","End call") if room.voice_adapter.requested else words("اتصال","Call")
 room.voice_mute_button.text=words("إلغاء الكتم","Unmute") if room.voice_adapter.muted else words("كتم","Mute")
 for node in [room.clock,room._clock_bar]:node.reparent(timer_slot)
 room.clock.visible=phase=="active" and int(value.get("timer",0))>0
 room.clock.add_theme_font_size_override("font_size",18)
 room._clock_bar.visible=room.clock.visible
 timer_slot.visible=room.clock.visible
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
 room_code.text=words("رمز الغرفة  %s","ROOM CODE  %s") % room.client.code
 lobby_players.text=words("اللاعبون  %d / %d","PLAYERS  %d / %d") % [int(value.get("joined",0)),count]
 room._agreement_info.text=words("الجاهزون %d/%d · %d جولات","Ready %d/%d · %d rounds") % [ready_count,count,int(party.get("rounds",10))]
 var game_title: String=str(room.SOCIAL_TITLES[category][0 if room.language=="ar" else 1])
 title.text=game_title+words(" · الغرفة %s"," · Room %s") % room.client.code if phase=="lobby" else game_title+words(" · الجولة %d/%d"," · Round %d/%d") % [mini(int(party.get("round",0))+(1 if phase=="active" else 0),int(party.get("rounds",10))),int(party.get("rounds",10))]
 card.visible=phase=="active"
 var actor: int=int(party.get("actor",-1))
 var own_turn: bool=actor==room.client.player
 instruction.text=words("دورك · شارك بالقدر الذي يريحك","Your turn · share as much as you feel comfortable") if own_turn else words("استمع إلى %s","Listen to %s") % room._social_player_name(actor)
 var prompt_data: Dictionary=party.get("card",{}) if party.get("card") is Dictionary else {}
 prompt.text=str(prompt_data.get("text_ar","")) if room.language=="ar" else str(prompt_data.get("text_en",prompt_data.get("text_ar","")))
 detail.text=words("بدون مؤقت · يمكنك التخطي دون خصم","No timer · skip without a penalty")
 if room.language=="en" and not prompt_data.has("text_en") and phase=="active":detail.text="This card is in Arabic. No timer · skip without a penalty."
 options.clear()
 if phase=="active":options.assign(_round_options(party,category,own_turn,int(value.get("capacity",2))))
 for i in range(option_buttons.size()):
  option_buttons[i].visible=i<options.size()
  if i<options.size():option_buttons[i].text=str(options[i].label)
 actions.layout_direction=room.layout_direction
 actions.columns=3 if options.size()>2 else 2
 next_round.visible=phase=="results" and room.client.player==0
 ranking.visible=phase in ["results","finished"]
 if category!="open_heart" and phase=="active":
  instruction.text=words("دورك الآن","Your turn") if own_turn else words("الدور على %s","Turn: %s") % room._social_player_name(actor)
  detail.text=words("اختر إجابتك عندما تكون مستعدًا","Choose your answer when ready")
  if category in ["act_it","show_skill"]:
   detail.text=words("مثّل الكارت لأصحابك" if category=="act_it" else "نفّذ التحدي لأصحابك","Perform the card for your friends") if own_turn else words("شاهد الأداء ثم صوّت","Watch the performance, then vote")
   if prompt_data.is_empty():prompt.text=words("الكارت سري عند صاحب الدور","The performer has the secret card")
  elif category=="truth_or_fiction":
   detail.text=words("ثبّت الحقيقة سرًا ثم احكِ القصة","Set the truth privately, then tell your story") if own_turn and not bool(party.get("story_committed",false)) else words("اسمع القصة ثم اختر: حقيقة أم تأليف؟","Listen, then choose: true or fiction?")
  elif category=="table_flip" and bool(party.get("choosing",false)):
   prompt.text=words("اختر كارت القوة","Choose a power card") if own_turn else words("صاحب الدور يختار كارتًا سريًا","The active player is choosing a private card")
  if str(room.client.player) in party.get("voted_players",[]):detail.text=words("تم تسجيل تصويتك · بانتظار الباقين","Vote recorded · waiting for the others")
 if phase=="lobby":
  instruction.text=words("اجمع أصحابك ثم استعدوا للعب","Gather your friends and get ready")
  detail.text=words("المشاركة = 10 نقاط · التخطي بدون خصم","Participation = 10 points · skipping has no penalty") if category=="open_heart" else words("لكل لاعب دوره · التصويت والنتائج تظهر في وقتها","Everyone has a role · votes and results reveal at the right time")
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
   var award_lines: Array[String]=[]
   for player in awarded:award_lines.append(room._social_player_name(int(player))+": "+("+" if int(awards[player])>0 else "")+str(int(awards[player])))
   detail.text=words("انتهت الجولة · لا تغيير في النقاط","Round complete · no score change") if awarded.is_empty() else " · ".join(award_lines)
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
 if not pending_key.is_empty() and ((pending_action=="duel_party_vote" and str(room.client.player) in party.get("voted_players",[])) or (pending_action=="duel_party_story" and bool(party.get("story_committed",false)))):
  pending_key=""
 for node in option_buttons+[next_round]:node.disabled=paused or not pending_key.is_empty()

func submit(kind: String, participated: bool=false) -> void:
 if not pending_key.is_empty() or bool(latest.get("paused",false)) or room.client.capabilities.is_empty():return
 var party: Dictionary=latest.get("party",{})
 var phase: String=str(party.get("phase",""))
 if kind=="finish" and (phase!="active" or str(party.get("actor",""))!=str(room.client.player)):return
 if kind=="next" and (phase!="results" or room.client.player!=0):return
 if kind=="next":_send("duel_party_next",{"round":int(party.get("round",0))})
 else:_send("duel_party_finish",{"card_id":str(party.get("card_id","")),"participated":participated})

func submit_option(index: int) -> void:
 if index<0 or index>=options.size() or not pending_key.is_empty():return
 var option: Dictionary=options[index]
 _send(str(option.action),option.fields)

func _send(action: String, fields: Dictionary) -> void:
 if not pending_key.is_empty() or bool(latest.get("paused",false)) or room.client.capabilities.is_empty():return
 var result: int=room.client.send_action(action,fields)
 if result!=OK:
  response.text=words("تعذر الإرسال · حاول مجددًا","Could not send · try again")
  return
 pending_key=phase_key;pending_action=action;pending_since=Time.get_ticks_msec()
 response.text=words("جار الإرسال…","Sending…")
 for node in option_buttons+[next_round]:node.disabled=true

func _round_options(party: Dictionary, category: String, own_turn: bool, capacity: int) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 var card_id: String=str(party.get("card_id",""))
 var voted: bool=str(room.client.player) in party.get("voted_players",[])
 if category=="open_heart" and own_turn:
  result.append({"label":words("شاركت · +10","Participated · +10"),"action":"duel_party_finish","fields":{"card_id":card_id,"participated":true}})
  result.append({"label":words("تخطي","Skip"),"action":"duel_party_finish","fields":{"card_id":card_id,"participated":false}})
 elif category=="who_among_us" and not voted:
  for i in range(capacity):
   if i!=room.client.player:result.append({"label":room._social_player_name(i),"action":"duel_party_vote","fields":{"card_id":card_id,"choice":str(i)}})
 elif category=="truth_or_fiction" and not bool(party.get("story_committed",false)):
  if own_turn:
   for truth in [true,false]:result.append({"label":words("حقيقية · اختيار سري" if truth else "تأليف · اختيار سري","True · private choice" if truth else "Fiction · private choice"),"action":"duel_party_story","fields":{"card_id":card_id,"is_true":truth}})
 elif category in ["act_it","show_skill","truth_or_fiction"] and not own_turn and not voted:
  for yes in [true,false]:result.append({"label":words(("حقيقية" if yes else "تأليف") if category=="truth_or_fiction" else ("نعم" if yes else "لا"),("True" if yes else "Fiction") if category=="truth_or_fiction" else ("Yes" if yes else "No")),"action":"duel_party_vote","fields":{"card_id":card_id,"choice":yes}})
 elif category=="table_flip" and own_turn:
  if bool(party.get("choosing",false)):
   for offer in party.get("offered",[]):result.append({"label":str(offer.get("text_"+room.language,offer.get("text_ar",""))),"action":"duel_party_choose","fields":{"card_id":str(offer.id)}})
  elif str(party.get("power","")) in ["bonus","steal","skip"]:
   for i in range(capacity):
    if i!=room.client.player:result.append({"label":room._social_player_name(i),"action":"duel_party_power","fields":{"card_id":card_id,"target":str(i)}})
  else:result.append({"label":words("نفّذ قوة الكارت","Apply card power"),"action":"duel_party_power","fields":{"card_id":card_id}})
 return result

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
