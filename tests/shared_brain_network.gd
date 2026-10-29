extends SceneTree
const Client=preload("res://scripts/photo_duel_extension_client.gd")
var peers=[]
var failures=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,name: String) -> void:
 print("QUIZ_CHECK ",name," ",ok)
 if not ok:failures.append(name)
func until(predicate: Callable) -> bool:
 var end=Time.get_ticks_msec()+6000
 while Time.get_ticks_msec()<end:
  if predicate.call():return true
  await create_timer(.02).timeout
 return false
func peer(game: String) -> Node:
 var c=Client.new();root.add_child(c);peers.append(c);c.requested_game=game;c.authenticate_local=true;c.terms_accepted=true;c.connect_endpoint("ws://127.0.0.1:8887");return c
func suite(count: int,game: String) -> void:
 var group=peers.slice(0,count)
 for c in group:
  if c.requested_game!=game:
   c.requested_game=game;c.connect_endpoint("ws://127.0.0.1:8887")
 var a=group[0]
 check(await until(func():return group.all(func(c):return c.capabilities.get("shared_quiz",false))),"%d clients authenticated game %s"%[count,game])
 a.send_action("duel_quiz_create",{"game_id":game,"players":count,"timer":10,"rounds":1,"difficulty":"easy"})
 check(await until(func():return not a.code.is_empty()),"room created")
 for i in range(1,count):group[i].join_room(a.code)
 check(await until(func():return group.all(func(c):return c.state.get("joined",0)==count)),"all real clients joined")
 for c in group:c.send_action("duel_accept",{"config_revision":int(c.state.config_revision),"picture_difficulty":c.state.picture_difficulty})
 check(await until(func():return a.state.confirmed.count(true)==count),"configuration accepted")
 a.send_action("duel_start")
 check(await until(func():return group.all(func(c):return c.state.get("quiz",{}).get("phase")=="question")),"same quiz starts")
 var q: Dictionary=a.state.quiz.question
 check(group.all(func(c):return c.state.quiz.question==q and c.state.quiz.start_unix_ms==a.state.quiz.start_unix_ms),"identical shuffled options and shared schedule")
 check(not a.state.quiz.has("correct_index") and not q.has("correct"),"answer absent before results")
 var errors: int=a.error_count
 a.send_action("duel_quiz_answer",{"question_id":q.id,"choice":0})
 check(await until(func():return a.error_count>errors),"pre countdown answer rejected")
 await create_timer(1.6).timeout
 if game=="6":
  var serial: int=int(a.state.quiz.audio_serial)
  group[1].send_action("duel_quiz_replay",{"question_id":q.id})
  check(await until(func():return group.all(func(c):return int(c.state.quiz.audio_serial)>serial)),"one replay schedule synchronized")
  check(group.all(func(c):return c.state.quiz.audio_start_unix_ms==a.state.quiz.audio_start_unix_ms),"shared replay timestamp")
  errors=a.error_count;a.send_action("duel_quiz_replay",{"question_id":q.id})
  check(await until(func():return a.error_count>errors),"second replay rejected")
 var bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))[game]
 var answer_text=""
 for original in bank:
  if original.id==q.id:answer_text=original.choices_ar[int(original.correct)]
 var correct_index: int=q.choices_ar.find(answer_text)
 check(correct_index>=0,"actual original catalog answer mapping")
 for i in range(count):
  group[i].send_action("duel_quiz_answer",{"question_id":q.id,"choice":correct_index if i<count-1 or count==2 else (correct_index+1)%q.choices_ar.size()})
  await create_timer(.12).timeout
 check(await until(func():return group.all(func(c):return c.state.quiz.phase=="finished")),"shared results and room retained")
 print("SCORING_EVIDENCE ",a.state.scores," ",a.state.quiz.results)
 check(a.state.scores[0]>a.state.scores[1],"fastest correct gets more server points")
 if count>2:check(a.state.scores[count-1]==0,"wrong answer receives zero")
 check(group.all(func(c):return c.state.scores==a.state.scores and c.state.quiz.correct_index==correct_index),"identical authoritative scoring and answer reveal")
 a.send_action("duel_leave");await create_timer(.1).timeout
 # Keep authenticated transports for subsequent room tests.
func run() -> void:
 create_timer(25).timeout.connect(func():print("BRAIN_QUIZ_TIMEOUT");quit(1))
 for i in range(2):peer("3")
 await suite(2,"3")
 print("BRAIN_QUIZ_REAL_GODOT_WS ",failures.is_empty()," ",failures)
 for c in peers:c.close_transport();c.queue_free()
 await process_frame;quit(0 if failures.is_empty() else 1)
