extends VBoxContainer
## Shared frame only: the existing photo/quiz controllers retain all game rules.
var host: Control
var game_panel: Control
var game_title := ""
var kind := ""
var background: ColorRect
var title: Label
var notice: Label
var scroll: ScrollContainer
var body: VBoxContainer
var timers: VBoxContainer
var reply_dock: VBoxContainer
var voice_dock: VBoxContainer
var result: Label
var result_trophy: Control
var result_standings: VBoxContainer
var more_button: Button
var phase_key := ""
var motion: Tween
var tools_open := false

func surface(color: Color) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(18)
 for edge in ["left","right","top","bottom"]:style.set("content_margin_"+edge,12)
 return style

func label_node(parent: Node, font_size: int) -> Label:
 var control:=Label.new();control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 control.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 control.add_theme_font_size_override("font_size",font_size)
 control.add_theme_color_override("font_color",Color("edf2ff"))
 control.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(control)
 return control

func setup(room: Control, panel: Control, title_text: String, game_kind: String) -> void:
 host=room;game_panel=panel;game_title=title_text;kind=game_kind
 host._fixed_voice_labels=true;host._navigation_view=self
 name="RoomPlayShell";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 offset_left=14;offset_right=-14;offset_top=12;offset_bottom=-12
 add_theme_constant_override("separation",8)
 background=ColorRect.new();background.color=Color("0b1032")
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter=Control.MOUSE_FILTER_IGNORE
 host.add_child(background);host.move_child(background,get_index())
 title=label_node(self,22);notice=label_node(self,14)
 timers=VBoxContainer.new();add_child(timers)
 scroll=ScrollContainer.new();scroll.follow_focus=true
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(scroll)
 body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",10);scroll.add_child(body)
 result_trophy=load("res://scripts/result_trophy.gd").new()
 result_trophy.visible=false;body.add_child(result_trophy)
 result=label_node(body,23)
 result_standings=VBoxContainer.new();result_standings.add_theme_constant_override("separation",6)
 result_standings.visible=false;body.add_child(result_standings)
 more_button=Button.new();more_button.text=host.tr_pair("خيارات الغرفة والإبلاغ","Room options & report")
 more_button.custom_minimum_size.y=44;more_button.pressed.connect(func():tools_open=not tools_open;host._settings_body.visible=tools_open)
 load("res://scripts/visual_skin.gd").decorate_play_action(more_button)
 body.add_child(more_button)
 reply_dock=VBoxContainer.new();add_child(reply_dock)
 voice_dock=VBoxContainer.new();voice_dock.custom_minimum_size.y=104;add_child(voice_dock)
 var leave:=Button.new();leave.text=host.tr_pair("مغادرة الغرفة","Leave room")
 leave.custom_minimum_size.y=44;load("res://scripts/visual_skin.gd").decorate_play_action(leave)
 leave.pressed.connect(func():host.confirm_room_leave());add_child(leave)
 hide();background.hide()

func before_snapshot() -> void:
 for node in [game_panel,host._seats,host._invite_box,host._agreement_box,host.clock,host._clock_bar,host._settings_body]:
  if node.get_parent()!=host._main_column:node.reparent(host._main_column)
 if kind=="photo" and host._reply_row.get_parent()!=game_panel:host._reply_row.reparent(game_panel)

func display(snapshot: Dictionary) -> void:
 var in_room: bool=not host.client.code.is_empty() and not bool(snapshot.get("closed",false))
 visible=in_room;background.visible=in_room;host._main_column.visible=not in_room
 if not in_room:
  if host._voice_controls.get_parent()!=host._main_column:host._voice_controls.reparent(host._main_column)
  phase_key=""
  return
 var quiz: Dictionary=snapshot.get("quiz",{})
 var question: Dictionary=quiz.get("question") if quiz.get("question") is Dictionary else {}
 var phase: String=str(quiz.get("phase","lobby")) if kind=="quiz" else ("finished" if snapshot.get("match_finished",false) else ("results" if snapshot.get("awaiting_next_round",false) else ("active" if snapshot.get("started",false) else "lobby")))
 # Quiz controls live outside the question panel in a fixed dock. Hide the
 # entire dock until the server actually supplies a question or its result.
 if kind=="quiz":reply_dock.visible=phase in ["question","results","finished"] and not question.is_empty()
 title.text=game_title+host.tr_pair(" · الغرفة %s"," · Room %s") % host.client.code if phase=="lobby" else game_title
 var paused: bool=bool(snapshot.get("paused",false)) or host.client.capabilities.is_empty()
 notice.text=host.tr_pair("جار استعادة الاتصال · انتظر عودة الغرفة","Reconnecting · waiting for the room") if paused else host.status.text
 host._seats.reparent(body);body.move_child(host._seats,0);host._seats.show()
 for i in range(host._seat_panels.size()):
  host._seat_avatars[i].custom_minimum_size=Vector2(24,24) if phase!="lobby" else Vector2(36,36)
  host._seat_labels[i].add_theme_font_size_override("font_size",14)
  # Keep the active photo player's turn visible after compacting the seats.
  # Quiz games are simultaneous, so they do not receive a turn highlight.
  var active_turn: bool=kind=="photo" and phase=="active" and not paused and int(snapshot.get("current",-1))==i
  var seat_style:=surface(Color("101d42"))
  seat_style.border_color=Color("59e4ff") if active_turn else Color("516ba7")
  seat_style.set_border_width_all(2 if active_turn else 1)
  if active_turn:
   seat_style.shadow_color=Color("35b8ff",.35);seat_style.shadow_size=5
  host._seat_panels[i].add_theme_stylebox_override("panel",seat_style)
  host._seat_statuses[i].visible=phase=="lobby"
  if phase!="lobby":
   var names: PackedStringArray=host._seat_labels[i].text.split("\n")
   host._seat_labels[i].text=names[0]+" · "+str(int(snapshot.get("scores",[])[i]) if i<snapshot.get("scores",[]).size() else 0)
   if i<snapshot.get("connected",[]).size() and not bool(snapshot.connected[i]):host._seat_labels[i].text+=" ↻"
 host._invite_box.reparent(body);host._invite_box.visible=phase=="lobby"
 host._agreement_box.reparent(body);host._agreement_box.visible=phase=="lobby" and bool(snapshot.get("room_agreement",false))
 game_panel.reparent(body)
 body.move_child(more_button,-1)
 host._settings_body.reparent(body);host._settings_body.visible=tools_open
 game_panel.visible=phase!="lobby" and (not question.is_empty() if kind=="quiz" else phase!="finished")
 # A trophy represents the server-confirmed winner only, never a draw or an
 # in-progress round. Scores and the actual winner remain server-owned.
 result_trophy.visible=phase=="finished" and int(snapshot.get("winner",-1))>=0
 result_standings.visible=kind=="photo" and phase=="finished"
 if result_standings.visible:render_scoreboard(result_standings,snapshot)
 if kind=="photo":
  host._reply_row.reparent(reply_dock)
  host.pass_button.reparent(reply_dock)
  host._reply_row.visible=phase=="active"
  result.visible=phase in ["results","finished"]
  result.text=host.status.text if phase=="finished" else host._scores.text+"\n"+host.status.text
 else:result.hide()
 for control in [host.clock,host._clock_bar]:control.reparent(timers)
 timers.visible=host.clock.visible
 host.clock.add_theme_font_size_override("font_size",19)
 host._voice_controls.reparent(voice_dock)
 voice_dock.visible=host._voice_controls.visible
 host.voice_status.custom_minimum_size.y=40;host.voice_status.max_lines_visible=2
 host.voice_status.add_theme_font_size_override("font_size",12)
 var next_key: String=host.client.code+":"+phase+":"+str(question.get("id",snapshot.get("round",0)))
 if next_key!=phase_key:
  phase_key=next_key;scroll.scroll_vertical=0
  if motion and motion.is_valid():motion.kill()
  game_panel.modulate.a=1.0
  if game_panel.visible and not bool(get_tree().root.get_meta("reduced_motion",false)):
   game_panel.modulate.a=0.5;motion=create_tween();motion.tween_property(game_panel,"modulate:a",1.0,.16)

func render_scoreboard(target: VBoxContainer, value: Dictionary) -> void:
 var scores: Array=value.get("scores",[])
 var profiles: Array=value.get("profiles",[])
 var winner: int=int(value.get("winner",-1))
 var key:=JSON.stringify([scores,profiles,winner,host.language,host.client.player])
 if key==str(target.get_meta("scoreboard_key","")):return
 target.set_meta("scoreboard_key",key)
 for child in target.get_children():
  target.remove_child(child);child.queue_free()
 var places: Array=[]
 for i in range(scores.size()):places.append({"player":i,"score":int(scores[i])})
 places.sort_custom(func(a,b):return a.score>b.score if a.score!=b.score else a.player<b.player)
 var prior_score: Variant=null
 var rank:=0
 for index in range(places.size()):
  var item: Dictionary=places[index]
  if prior_score==null or int(item.score)!=int(prior_score):rank=index+1
  prior_score=item.score
  var player: int=int(item.player)
  var profile: Dictionary=profiles[player] if player<profiles.size() and profiles[player] is Dictionary else {}
  var player_name: String=str(profile.get("display_name","")).strip_edges().left(40)
  if player_name.is_empty():player_name=host.tr_pair("اللاعب %d","Player %d") % (player+1)
  if player==host.client.player:player_name+=host.tr_pair(" • أنت"," • You")
  var panel:=PanelContainer.new();panel.set_meta("player_index",player)
  var row_style: StyleBoxFlat=load("res://scripts/visual_skin.gd").card(Color("0a1d48"),14)
  row_style.border_color=Color("ffd76a") if player==winner else Color("4985ce")
  row_style.set_border_width_all(1);row_style.shadow_size=0
  row_style.content_margin_top=5;row_style.content_margin_bottom=5
  panel.add_theme_stylebox_override("panel",row_style);target.add_child(panel)
  var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);panel.add_child(row)
  var place:=Label.new();place.text=str(rank);place.add_theme_color_override("font_color",Color("ffd76a"));row.add_child(place)
  var name_label:=Label.new();name_label.text=player_name;name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(name_label)
  var points:=Label.new();points.text=str(item.score);points.add_theme_color_override("font_color",Color("ffffff"));row.add_child(points)
