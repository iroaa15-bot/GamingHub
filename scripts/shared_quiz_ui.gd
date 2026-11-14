extends "res://scripts/photo_duel_extension_ui.gd"
# Game-specific questions and playback; membership/voice/chat remain the original shared components.
static var selected_game := "1"
var quiz_panel: VBoxContainer
var quiz_title: Label
var quiz_question_card: PanelContainer
var sound_progress: ProgressBar
var quiz_results: Label
var answer_buttons: Array[Button]=[]
var next_button: Button
var replay_button: Button
var audio_player: AudioStreamPlayer
var current_question := ""
var written_field: LineEdit
var written_submit: Button
var clue_control: Button
var mechanic_info: Label
var steps_box: VBoxContainer
var step_picks: Array[int]=[]
var step_controls: Array[Button]=[]
var order_submit: Button
var order_undo: Button
var question_image: TextureRect
var scene_video: VideoStreamPlayer
var scene_replay: Button
var story_text: Label
var memory_grid: GridContainer
var memory_controls: Array[Button]=[]
var memory_sync_at: int=0
var _sound_phase_key: String=""
var _server_offset := 0
var _audio_serial := -1
var _audio_start := 0
var _audio_pending := false
var _quiz_categories_ready := false
func _ready() -> void:
 super._ready()
 var title_text: String={"1":tr_pair("تحدي السينما","Cinema Challenge"),"3":tr_pair("تحدي التفكير","Brain Clash"),"4":tr_pair("رحلة الأسرار","Mystery Quest"),"5":tr_pair("ساحة المعلومات","Trivia Arena"),"8":tr_pair("ذاكرة الصور","Picture Memory"),"2":tr_pair("معركة الكلمات","Word Battle"),"7":tr_pair("من أنا؟","Who Am I?"),"9":tr_pair("ترتيب الخطوات","Step Builder"),"6":tr_pair("خمن الصوت","Guess the Sound")}.get(selected_game, tr_pair("غرفة الأسئلة","Quiz room"))
 for child in _main_column.get_children():
  if child.name=="CompactHeader":
   for entry in child.get_children():
    if entry is Label:entry.text=title_text
 client.requested_game=selected_game
 target_field.value=5
 for child in _settings_body.get_children():
  if child is Label and child.text in ["نقاط الفوز","Winning score"]:child.text=tr_pair("عدد الأسئلة","Number of questions")
 column=_main_column
 quiz_panel=VBoxContainer.new();quiz_panel.add_theme_constant_override("separation",8);_main_column.add_child(quiz_panel)
 scene_video=VideoStreamPlayer.new()
 scene_video.expand=true
 scene_video.custom_minimum_size.y=180
 quiz_panel.add_child(scene_video)
 scene_video.hide()
 scene_replay=button(tr_pair("شغّل المشهد","Play scene"),func():
  if scene_video.stream!=null:
   scene_video.stop()
   scene_video.play()
 )
 scene_replay.hide()
 column=quiz_panel
 quiz_title=label("",21)
 quiz_question_card=PanelContainer.new();quiz_question_card.name="QuizQuestionCard"
 var question_skin:=VisualSkin.card(Color("20154c"),22)
 question_skin.border_color=VisualSkin.SUN if selected_game=="1" else VisualSkin.CYAN
 quiz_question_card.add_theme_stylebox_override("panel",question_skin)
 quiz_panel.add_child(quiz_question_card);quiz_panel.move_child(quiz_question_card,0)
 quiz_title.reparent(quiz_question_card)
 sound_progress=ProgressBar.new();sound_progress.name="SoundPlaybackProgress";sound_progress.show_percentage=false
 VisualSkin.decorate_progress(sound_progress);quiz_panel.add_child(sound_progress);sound_progress.hide()
 story_text=label("")
 question_image=TextureRect.new();question_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;question_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;question_image.custom_minimum_size.y=180;quiz_panel.add_child(question_image)
 memory_grid=GridContainer.new();memory_grid.columns=4;memory_grid.add_theme_constant_override("h_separation",6);memory_grid.add_theme_constant_override("v_separation",6);quiz_panel.add_child(memory_grid)
 replay_button=button(tr_pair("إعادة الصوت للجميع • مرة واحدة","Replay for everyone • once"),func():client.send_action("duel_quiz_replay",{"question_id":current_question}))
 for i in range(6):
  var index: int=i
  answer_buttons.append(button("",func():client.send_action("duel_quiz_answer",{"question_id":current_question,"choice":index})))
 written_field=LineEdit.new();written_field.placeholder_text=tr_pair("اكتب إجابتك","Type your answer");written_field.max_length=200;VisualSkin.decorate_input(written_field);quiz_panel.add_child(written_field)
 written_submit=button(tr_pair("تأكيد الإجابة","Confirm answer"),func():client.send_action("duel_quiz_answer",{"question_id":current_question,"text":written_field.text}))
 mechanic_info=label("")
 clue_control=button(tr_pair("دليل إضافي • يخفض النقاط","Another clue • reduces points"),func():client.send_action("duel_quiz_clue",{"question_id":current_question}))
 steps_box=VBoxContainer.new();quiz_panel.add_child(steps_box)
 order_undo=button(tr_pair("إعادة ترتيب البداية","Reset arrangement"),_reset_step_order)
 order_submit=button(tr_pair("تحقق من الترتيب","Check order"),func():client.send_action("duel_quiz_answer",{"question_id":current_question,"sequence":step_picks}))
 quiz_results=label("")
 next_button=button(tr_pair("السؤال التالي","Next question"),func():client.send_action("duel_quiz_next"))
 column=_main_column
 load("res://scripts/room_audio_policy.gd").acquire(get_tree())
 audio_player=AudioStreamPlayer.new();audio_player.bus="Game SFX";audio_player.volume_db=-8;add_child(audio_player)
 _quiz_state(client.state)
 client.state_changed.connect(_quiz_state)
func _create_filtered_room() -> void:
 client.send_action("duel_quiz_create",{"game_id":selected_game,"players":players_field.get_selected_id(),"timer":timer_field.get_selected_id(),"rounds":int(target_field.value),"difficulty":_online_rank_keys[_online_rank.selected]})
func _propose_configuration() -> void:
 client.send_action("duel_quiz_propose",{"category":_online_category_keys[_online_category.selected],"primary_mode":"tap"})
func _state(value: Dictionary) -> void:
 super._state(value)
 _match_controls.hide()
 _mode_field.hide()
 _voice_question.hide()
 clock.visible=not client.code.is_empty() and not bool(value.get("closed",false)) and value.get("quiz",{}).get("phase")=="question"
 if not clock.visible:_clock_bar.hide()
 if not is_instance_valid(client):return
 create_button.disabled=create_button.disabled or (not client.capabilities.is_empty() and not bool(client.capabilities.get("shared_quiz",false)))
 if client.capabilities.get("quiz_categories") is Dictionary and not _quiz_categories_ready:
  _quiz_categories_ready=true;_online_category.clear();_online_category_keys=["all"]
  _online_category.add_item(tr_pair("كل الموضوعات","All topics"))
  for key in client.capabilities.quiz_categories:
   _online_category_keys.append(key);_online_category.add_item(str(client.capabilities.quiz_categories[key].get(language,key)))
 if not client.code.is_empty() and _configuration_changed:
  var index: int=_online_category_keys.find(value.get("picture_category","all"))
  if index>=0 and index<_online_category.item_count:_online_category.select(index)
 if is_instance_valid(quiz_panel):
  if value.get("quiz",{}).get("phase") in ["question","results","finished"]:
   _seats.reparent(quiz_panel)
   heading.text=tr_pair("الجميع يجيب الآن","Everyone answers together") if value.quiz.phase=="question" else tr_pair("نتائج الجولة","Round results")
   _main_column.move_child(quiz_panel,_main_column.get_children().find(_match_controls))
  _quiz_state(value)
func _quiz_state(value: Dictionary) -> void:
 if not is_instance_valid(quiz_panel):return
 var quiz: Dictionary=value.get("quiz",{})
 var question: Dictionary=quiz.get("question") if quiz.get("question") is Dictionary else {}
 quiz_panel.visible=not question.is_empty() and not bool(value.get("closed",false))
 if not quiz_panel.visible:
  scene_video.stop()
  scene_video.stream=null
  scene_video.hide()
  scene_replay.hide()
  audio_player.stop()
  audio_player.stream_paused=false
  _audio_pending=false
  _audio_serial=-1
  _sound_phase_key=""
  return
 var phase: String=str(quiz.get("phase",""))
 var sound_key: String=str(question.get("id",""))+":"+phase
 if sound_key!=_sound_phase_key:
  _sound_phase_key=sound_key
  var audio_policy=load("res://scripts/room_audio_policy.gd").acquire(get_tree())
  if phase=="question":audio_policy.effect("round_start")
  elif phase in ["results","finished"]:
   audio_player.stop();audio_policy.sample_playback(self,false)
   var own_correct: bool=false
   for result in quiz.get("results",[]):
    if int(result.player)==client.player:own_correct=bool(result.correct)
   audio_policy.effect("correct" if own_correct else "incorrect")
   if phase=="finished":
    var scores: Array=value.get("scores",[])
    var won: bool=client.player>=0 and client.player<scores.size() and scores[client.player]==scores.max()
    get_tree().create_timer(.65).timeout.connect(func():audio_policy.effect("victory" if won else "results"))
 status.text=tr_pair("تحدٍ متزامن للجميع","Synchronized challenge for everyone") if phase=="question" else tr_pair("نتائج مشتركة لكل اللاعبين","Shared results for all players")
 _server_offset=int(quiz.get("server_unix_ms",Time.get_unix_time_from_system()*1000))-int(Time.get_unix_time_from_system()*1000)
 var changed: bool=current_question!=str(question.get("id",""))
 current_question=str(question.get("id",""))
 var mechanic: String=str(question.get("mode","choice"))
 story_text.text=str(question.get("narrative_"+language,question.get("narrative_en","")))
 story_text.visible=not story_text.text.is_empty()
 var image_path: String=str(question.get("image",""))
 question_image.visible=image_path.begins_with("res://assets/") and ResourceLoader.exists(image_path)
 if changed:question_image.texture=load(image_path) if question_image.visible else null
 var video_path: String=str(question.get("video",""))
 if changed or scene_video.stream==null:
  scene_video.stop()
  scene_video.stream=null
  if video_path.begins_with("res://assets/cinema/") and video_path.get_extension()=="ogv" and ResourceLoader.exists(video_path):
   scene_video.stream=load(video_path) as VideoStream
 scene_video.visible=scene_video.stream!=null and phase=="question"
 scene_replay.visible=scene_video.visible
 scene_replay.disabled=bool(value.get("paused",false))
 scene_video.paused=scene_replay.disabled
 if not scene_video.visible:scene_video.stop()
 memory_grid.visible=mechanic=="memory"
 var can_answer: bool=phase=="question" and not bool(value.get("paused",false)) and quiz.get("your_answer")==null and _quiz_now()>=int(quiz.get("start_unix_ms",0))
 written_field.visible=mechanic in ["write","identity"];written_submit.visible=written_field.visible
 written_field.editable=can_answer;written_submit.disabled=not can_answer
 clue_control.visible=mechanic=="identity";clue_control.disabled=not can_answer or not bool(quiz.get("more_clues",false))
 mechanic_info.visible=mechanic in ["identity","order"]
 if mechanic=="identity":mechanic_info.text="\n".join(quiz.get("clues",{}).get(language,quiz.get("clues",{}).get("en",[])))
 steps_box.visible=mechanic=="order";order_submit.visible=steps_box.visible;order_undo.visible=steps_box.visible
 if changed:
  written_field.clear();step_picks.clear();step_controls.clear();memory_controls.clear()
  for child in memory_grid.get_children():child.queue_free()
  for i in range(int(question.get("size",0))):
   var card_index: int=i
   var card=Button.new();card.text="?";card.custom_minimum_size=Vector2(72,78);card.expand_icon=true;card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
   VisualSkin.decorate_button(card,"violet");card.add_theme_constant_override("icon_max_width",52);card.add_theme_color_override("icon_disabled_color",Color.WHITE)
   card.pressed.connect(func():client.send_action("duel_quiz_flip",{"question_id":current_question,"index":card_index}))
   memory_grid.add_child(card);memory_controls.append(card)
  for child in steps_box.get_children():child.queue_free()
  var steps: Array=question.get("steps_"+language,question.get("steps_en",[]))
  for i in range(steps.size()):
   var index: int=i
   var control=load("res://scripts/order_drag_item.gd").new();control.text=str(steps[i]);control.custom_minimum_size.y=56
   VisualSkin.decorate_button(control,"teal");control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
   control.item_index=index;control.group_key=current_question
   control.move_requested.connect(_move_step_order,CONNECT_DEFERRED)
   steps_box.add_child(control);step_controls.append(control)
  step_picks.assign(range(steps.size()))
 if mechanic=="memory":
  var board: Dictionary=quiz.get("memory",{})
  mechanic_info.visible=true;mechanic_info.text=tr_pair("المحاولات: %d","Moves: %d") % int(board.get("moves",0))
  memory_sync_at=int(board.get("hide_unix_ms",0))
  for i in range(memory_controls.size()):
   var shown: Dictionary=board.get("revealed",{}).get(str(i),{})
   var card=memory_controls[i]
   card.text=str(shown.get(language,shown.get("en","?")))
   var path: String=str(shown.get("image",""))
   card.icon=load(path) if path.begins_with("res://assets/") and ResourceLoader.exists(path) else null
   card.tooltip_text=card.text
   if card.icon!=null:card.text=""
   card.disabled=not can_answer or float(i) in board.get("matched",[]) or (memory_sync_at>_quiz_now()) or not shown.is_empty()
 if mechanic=="order":
  for i in range(step_controls.size()):step_controls[i].disabled=not can_answer
  order_submit.disabled=not can_answer or step_picks.size()!=step_controls.size();order_undo.disabled=not can_answer or step_picks.is_empty()
  _show_step_picks()
 quiz_title.text=tr_pair("سؤال %d من %d • ","Question %d of %d • ") % [int(quiz.get("round",1)),int(quiz.get("rounds",1))]+str(question.get(language,question.get("en","")))
 var choices: Array=question.get("choices_"+language,question.get("choices_en",[]))
 for i in range(answer_buttons.size()):
  answer_buttons[i].visible=mechanic=="choice" and i<choices.size()
  if i<choices.size():answer_buttons[i].text=str(choices[i])
  answer_buttons[i].disabled=phase!="question" or bool(value.get("paused",false)) or quiz.get("your_answer")!=null or _quiz_now()<int(quiz.get("start_unix_ms",0))
  # Correctness is revealed by the server only after the question phase.
  var revealed: bool=phase in ["results","finished"] and quiz.has("correct_index")
  var correct_choice: bool=revealed and i==int(quiz.get("correct_index",-1))
  var wrong_choice: bool=revealed and not correct_choice and quiz.get("your_answer")==i
  VisualSkin.decorate_button(answer_buttons[i],"teal" if correct_choice else ("danger" if wrong_choice else "secondary"))
  if correct_choice or wrong_choice:
   answer_buttons[i].add_theme_stylebox_override("disabled",answer_buttons[i].get_theme_stylebox("normal"))
   answer_buttons[i].text=("✓ " if correct_choice else "✕ ")+answer_buttons[i].text
 replay_button.visible=question.has("audio") and phase=="question"
 sound_progress.visible=replay_button.visible
 replay_button.disabled=not bool(quiz.get("replay_available",false)) or bool(value.get("paused",false)) or _quiz_now()<int(quiz.get("start_unix_ms",0))
 next_button.visible=phase=="results" and client.player==0
 var lines := PackedStringArray()
 lines.append(tr_pair("الإجابات: %d/%d","Answers: %d/%d") % [int(quiz.get("answered_count",0)),int(value.get("capacity",2))])
 if quiz.has("answer_labels"):lines.append(str(quiz.answer_labels.get(language,quiz.answer_labels.get("en",""))))
 if quiz.has("correct_sequence"):
  var ordered: Array=[]
  var steps: Array=question.get("steps_"+language,question.get("steps_en",[]))
  for index in quiz.correct_sequence:ordered.append(str(steps[int(index)]))
  lines.append(" → ".join(ordered))
 if quiz.has("correct_index"):
  var correct: int=int(quiz.correct_index)
  if correct>=0 and correct<choices.size():lines.append(tr_pair("الإجابة: ","Answer: ")+str(choices[correct]))
 for row in quiz.get("results",[]):lines.append(tr_pair("اللاعب %d: %d نقطة","Player %d: %d points") % [int(row.player)+1,int(row.points)])
 quiz_results.text="\n".join(lines)
 var serial: int=int(quiz.get("audio_serial",-1))
 if phase!="question":audio_player.stop();audio_player.stream_paused=false;_audio_pending=false
 elif bool(value.get("paused",false)):audio_player.stream_paused=true
 elif question.has("audio") and serial!=_audio_serial:
  _audio_serial=serial;_audio_start=int(quiz.get("audio_start_unix_ms",0));_audio_pending=true
  var path: String=str(question.audio)
  if path.begins_with("res://assets/audio/") and path.get_extension() in ["wav","ogg"] and ResourceLoader.exists(path):audio_player.stream=load(path)
  else:_audio_pending=false
 if phase=="question" and not bool(value.get("paused",false)):
  audio_player.stream_paused=false
  _audio_start=int(quiz.get("audio_start_unix_ms",_audio_start))
func _show_step_picks() -> void:
 mechanic_info.text=tr_pair("اسحب العناصر لترتيبها ثم اضغط تأكيد.","Drag the items into order, then confirm.")
 var enabled: bool=_can_order_now()
 order_submit.disabled=not enabled or step_picks.size()!=step_controls.size()
 order_undo.disabled=not enabled
 for control in step_controls:
  control.disabled=not enabled;control.ordering_enabled=enabled

func _can_order_now() -> bool:
 var quiz: Dictionary=client.state.get("quiz",{})
 return quiz.get("phase")=="question" and quiz.get("your_answer")==null and not bool(client.state.get("paused",false)) and _quiz_now()>=int(quiz.get("start_unix_ms",0))

func _move_step_order(source: int,target: int) -> void:
 if not _can_order_now() or source not in step_picks or target not in step_picks:return
 var destination: int=step_picks.find(target)
 step_picks.erase(source);step_picks.insert(destination,source)
 _sync_order_nodes()

func _reset_step_order() -> void:
 if not _can_order_now():return
 step_picks.assign(range(step_controls.size()))
 _sync_order_nodes()

func _sync_order_nodes() -> void:
 for position in range(step_picks.size()):steps_box.move_child(step_controls[step_picks[position]],position)
 _show_step_picks()

func _quiz_now() -> int:return int(Time.get_unix_time_from_system()*1000)+_server_offset
func _process(delta: float) -> void:
 super._process(delta)
 if is_instance_valid(sound_progress) and is_instance_valid(audio_player) and audio_player.stream!=null:
  sound_progress.max_value=maxf(.001,audio_player.stream.get_length())
  sound_progress.value=audio_player.get_playback_position()
 load("res://scripts/room_audio_policy.gd").acquire(get_tree()).sample_playback(self,is_instance_valid(audio_player) and audio_player.playing and not audio_player.stream_paused)
 if not is_instance_valid(client) or not is_instance_valid(quiz_panel) or not quiz_panel.visible:return
 var quiz: Dictionary=client.state.get("quiz",{})
 if memory_sync_at>0 and _quiz_now()>=memory_sync_at:
  memory_sync_at=0;client.send_action("duel_sync")
 if quiz.get("phase")=="question" and not bool(client.state.get("paused",false)):
  if quiz.get("your_answer")==null and _quiz_now()>=int(quiz.get("start_unix_ms",0)):
   replay_button.disabled=not bool(quiz.get("replay_available",false))
   for b in answer_buttons:b.disabled=false
   if str(quiz.get("question",{}).get("mode",""))=="memory":
    var board: Dictionary=quiz.get("memory",{})
    for i in range(memory_controls.size()):memory_controls[i].disabled=float(i) in board.get("matched",[]) or board.get("revealed",{}).has(str(i)) or memory_sync_at>_quiz_now()
   written_field.editable=true;written_submit.disabled=false
   clue_control.disabled=not bool(quiz.get("more_clues",false))
   for control in step_controls:control.disabled=false;control.ordering_enabled=true
   order_submit.disabled=step_picks.size()!=step_controls.size();order_undo.disabled=step_picks.is_empty()
  if _audio_pending and _quiz_now()>=_audio_start:
   _audio_pending=false
   var elapsed: float=maxf(0,float(_quiz_now()-_audio_start)/1000.0)
   if is_instance_valid(audio_player.stream) and elapsed<audio_player.stream.get_length():audio_player.play(elapsed)

func _exit_tree() -> void:
 var policy=get_tree().root.get_node_or_null("RoomAudioPolicy")
 if policy!=null:policy.sample_playback(self,false)
