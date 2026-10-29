extends "res://scripts/photo_duel_extension_ui.gd"
# Game-specific questions and playback; membership/voice/chat remain the original shared components.
static var selected_game := "1"
var quiz_panel: VBoxContainer
var quiz_title: Label
var quiz_results: Label
var answer_buttons: Array[Button]=[]
var next_button: Button
var replay_button: Button
var audio_player: AudioStreamPlayer
var current_question := ""
var _sound_phase_key: String=""
var _server_offset := 0
var _audio_serial := -1
var _audio_start := 0
var _audio_pending := false
var _quiz_categories_ready := false
func _ready() -> void:
 super._ready()
 var title_text: String=tr_pair("تحدي السينما","Cinema Challenge") if selected_game=="1" else tr_pair("خمن الصوت","Guess the Sound")
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
 column=quiz_panel
 quiz_title=label("",21)
 replay_button=button(tr_pair("إعادة الصوت للجميع • مرة واحدة","Replay for everyone • once"),func():client.send_action("duel_quiz_replay",{"question_id":current_question}))
 for i in range(6):
  var index: int=i
  answer_buttons.append(button("",func():client.send_action("duel_quiz_answer",{"question_id":current_question,"choice":index})))
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
 client.send_action("duel_quiz_propose",{"category":_online_category_keys[_online_category.selected],"primary_mode":["voice","text","tap"][_mode_field.selected]})
func _state(value: Dictionary) -> void:
 super._state(value)
 _match_controls.hide()
 clock.visible=value.get("quiz",{}).get("phase")=="question"
 if not is_instance_valid(client):return
 create_button.disabled=create_button.disabled or (not client.capabilities.is_empty() and not bool(client.capabilities.get("shared_quiz",false)))
 if client.capabilities.get("quiz_categories") is Dictionary and not _quiz_categories_ready:
  _quiz_categories_ready=true;_online_category.clear();_online_category_keys=["all"]
  _online_category.add_item(tr_pair("كل الموضوعات","All topics"))
  for key in client.capabilities.quiz_categories:
   _online_category_keys.append(key);_online_category.add_item(str(client.capabilities.quiz_categories[key].get(language,key)))
 if not client.code.is_empty():
  var index: int=_online_category_keys.find(value.get("picture_category","all"))
  if index>=0:_online_category.select(index)
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
  audio_player.stop();return
 var phase: String=str(quiz.get("phase",""))
 var sound_key: String=str(question.get("id",""))+":"+phase
 if sound_key!=_sound_phase_key:
  _sound_phase_key=sound_key
  var audio_policy=load("res://scripts/room_audio_policy.gd").acquire(get_tree())
  if phase=="question":audio_policy.effect("round_start")
  elif phase in ["results","finished"]:
   audio_player.stop();audio_policy.sample_playback(self,false)
   audio_policy.effect("correct" if quiz.get("your_answer")==quiz.get("correct_index") and quiz.get("your_answer")!=null else "incorrect")
   if phase=="finished":
    var scores: Array=value.get("scores",[])
    var won: bool=client.player>=0 and client.player<scores.size() and scores[client.player]==scores.max()
    get_tree().create_timer(.65).timeout.connect(func():audio_policy.effect("victory" if won else "results"))
 status.text=tr_pair("نفس السؤال للجميع • اختر إجابة واحدة","Same question for everyone • choose one answer") if phase=="question" else tr_pair("نتائج مشتركة لكل اللاعبين","Shared results for all players")
 _server_offset=int(quiz.get("server_unix_ms",Time.get_unix_time_from_system()*1000))-int(Time.get_unix_time_from_system()*1000)
 current_question=str(question.get("id",""))
 quiz_title.text=tr_pair("سؤال %d من %d • ","Question %d of %d • ") % [int(quiz.get("round",1)),int(quiz.get("rounds",1))]+str(question.get(language,question.get("en","")))
 var choices: Array=question.get("choices_"+language,question.get("choices_en",[]))
 for i in range(answer_buttons.size()):
  answer_buttons[i].visible=i<choices.size()
  if i<choices.size():answer_buttons[i].text=str(choices[i])
  answer_buttons[i].disabled=phase!="question" or bool(value.get("paused",false)) or quiz.get("your_answer")!=null or _quiz_now()<int(quiz.get("start_unix_ms",0))
 replay_button.visible=question.has("audio") and phase=="question"
 replay_button.disabled=not bool(quiz.get("replay_available",false)) or bool(value.get("paused",false))
 next_button.visible=phase=="results" and client.player==0
 var lines := PackedStringArray()
 lines.append(tr_pair("الإجابات: %d/%d","Answers: %d/%d") % [int(quiz.get("answered_count",0)),int(value.get("capacity",2))])
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
  if path.begins_with("res://assets/audio/") and path.ends_with(".wav") and ResourceLoader.exists(path):audio_player.stream=load(path)
  else:_audio_pending=false
 if phase=="question" and not bool(value.get("paused",false)):
  audio_player.stream_paused=false
  _audio_start=int(quiz.get("audio_start_unix_ms",_audio_start))
func _quiz_now() -> int:return int(Time.get_unix_time_from_system()*1000)+_server_offset
func _process(delta: float) -> void:
 super._process(delta)
 load("res://scripts/room_audio_policy.gd").acquire(get_tree()).sample_playback(self,is_instance_valid(audio_player) and audio_player.playing and not audio_player.stream_paused)
 if not is_instance_valid(client) or not is_instance_valid(quiz_panel):return
 var quiz: Dictionary=client.state.get("quiz",{})
 if quiz.get("phase")=="question" and not bool(client.state.get("paused",false)):
  if quiz.get("your_answer")==null and _quiz_now()>=int(quiz.get("start_unix_ms",0)):
   for b in answer_buttons:b.disabled=false
  if _audio_pending and _quiz_now()>=_audio_start:
   _audio_pending=false
   var elapsed: float=maxf(0,float(_quiz_now()-_audio_start)/1000.0)
   if is_instance_valid(audio_player.stream) and elapsed<audio_player.stream.get_length():audio_player.play(elapsed)

func _exit_tree() -> void:
 var policy=get_tree().root.get_node_or_null("RoomAudioPolicy")
 if policy!=null:policy.sample_playback(self,false)
