extends SceneTree
var failures=[]
var endpoint="ws://127.0.0.1:8889"
var folder="C:/Users/Omar/Documents/GitHub/GamingHub/release/shared_remaining_20261029/screens"
func _initialize() -> void:call_deferred("run")
func ck(ok: bool,name: String) -> void:
 print("MECHANICS_UI ",name," ",ok)
 if not ok:failures.append(name)
func until(predicate: Callable) -> bool:
 var end=Time.get_ticks_msec()+7000
 while Time.get_ticks_msec()<end:
  if predicate.call():return true
  await create_timer(.025).timeout
 return false
func snap(name: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func solve_memory(ui: Node) -> void:
 var remembered: Dictionary={}
 var count: int=int(ui.client.state.quiz.question.size)
 var attempts: int=0
 while ui.client.state.quiz.phase=="question" and ui.client.state.quiz.your_answer==null and attempts<30:
  attempts+=1
  var board: Dictionary=ui.client.state.quiz.memory
  var matched: Array=board.matched.map(func(x):return int(x))
  var first: int=-1
  var second: int=-1
  for i in remembered:
   if int(i) in matched:continue
   for j in remembered:
    if int(j)!=int(i) and int(j) not in matched and remembered[j]==remembered[i]:first=int(i);second=int(j);break
   if first>=0:break
  if first<0:
   for i in range(count):
    if i not in matched and not remembered.has(i):first=i;break
  if first<0:break
  print("MEMORY_STEP ",attempts," first ",first," matched ",matched," status ",ui.status.text)
  ui.memory_controls[first].pressed.emit()
  if not await until(func():return ui.client.state.quiz.memory.revealed.has(str(first))):break
  remembered[first]=ui.client.state.quiz.memory.revealed[str(first)].en
  ck(ui.memory_controls[first].icon!=null and ui.memory_controls[first].text.is_empty(),"revealed picture remains readable without inline caption shrinking it")
  if attempts==1:await snap("8-memory-revealed")
  if second<0:
   for i in remembered:
    if int(i)!=first and int(i) not in matched and remembered[i]==remembered[first]:second=int(i);break
  if second<0:
   for i in range(count):
    if i!=first and i not in matched and not remembered.has(i):second=i;break
  if second<0:
   for i in range(count):
    if i!=first and i not in matched:second=i;break
  ui.memory_controls[second].pressed.emit()
  await create_timer(.1).timeout
  var shown: Dictionary=ui.client.state.quiz.memory.revealed
  if shown.has(str(second)):remembered[second]=shown[str(second)].en
  await create_timer(1.7).timeout
  ui.client.send_action("duel_sync");await create_timer(.08).timeout
 ck(ui.client.state.quiz.your_answer==true,"memory solved by real flip callbacks without board disclosure")
func arrange_steps(ui: Node, q: Dictionary, original: Dictionary) -> void:
 # Emit the same move signal used by drag-and-drop; the controls retain their
 # original indices while their visual order changes.
 for position in range(original.steps_ar.size()):
  var desired: int=q.steps_ar.find(original.steps_ar[position])
  var target: int=ui.step_picks[position]
  if desired!=target:
   ui.step_controls[desired].move_requested.emit(desired,target)
   await process_frame;await process_frame
func suite(game: String) -> void:
 var script=load("res://scripts/shared_quiz_ui.gd");script.selected_game=game
 var a=script.new();root.add_child(a);a.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var b=script.new();root.add_child(b);b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);b.hide()
 a.service_endpoint=endpoint;a.terms.button_pressed=true;a.target_field.value=1
 # The fixture solves two private boards sequentially, so use the real
 # untimed option rather than letting the round expire before player two acts.
 if game=="8":a.timer_field.select(0)
 a._request_room_action("create")
 if not await until(func():return not a.client.code.is_empty()):ck(false,game+" create: "+a.status.text);quit(1);return
 b.service_endpoint=endpoint;b.terms.button_pressed=true;b.code_field.text=a.client.code;b._request_room_action("join")
 ck(await until(func():return a.client.state.get("joined",0)==2 and b.client.state.get("joined",0)==2),game+" real UI join")
 if game=="8":
  a.client.send_action("duel_quiz_propose",{"category":"Place","primary_mode":"text"})
  await until(func():return b.client.state.picture_category=="Place")
 a._accept_configuration();b._accept_configuration()
 await until(func():return a.client.state.confirmed.count(true)==2)
 ck(await until(func():return a.quiz_panel.visible and b.quiz_panel.visible),game+" actual controls visible")
 ck(a.client.state.quiz.question==b.client.state.quiz.question,game+" same question payload")
 # Both clients must reach the server's start time before controls are used.
 # Fixed sleeps can race initialization on slower devices or CI runners.
 var ready: bool=await until(func():return a.client.state.get("quiz",{}).get("phase")=="question" and b.client.state.get("quiz",{}).get("phase")=="question" and a._quiz_now()>=int(a.client.state.quiz.get("start_unix_ms",0))+200 and b._quiz_now()>=int(b.client.state.quiz.get("start_unix_ms",0))+200)
 ck(ready,game+" both players passed the countdown")
 if not ready:
  for ui in [a,b]:ui.client.close_transport();ui.queue_free()
  await process_frame;return
 var q: Dictionary=a.client.state.quiz.question
 var mode: String=q.get("mode","choice")
 await snap(game+"-"+mode)
 var original: Dictionary={}
 if game!="8":
  var bank: Dictionary=load("res://scripts/approved_content.gd").questions(JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json")))
  for item in bank[game]:
   if item.id==q.id:original=item
 if mode in ["write","identity"]:
  ck(a.written_field.visible and not a.answer_buttons[0].visible,game+" typed controls not MCQ")
  if mode=="identity":
   a.clue_control.pressed.emit();ck(await until(func():return a.client.state.quiz.clues.ar.size()==2),"private progressive clue")
   ck(b.client.state.quiz.clues.ar.size()==1,"opponent clue remains private")
  a.written_field.text=original.answers_ar[0];b.written_field.text="wrong"
  a.written_submit.pressed.emit();b.written_submit.pressed.emit()
 elif mode=="order":
  ck(a.order_submit.visible and not a.answer_buttons[0].visible,"ordering retains step selection")
  await arrange_steps(a,q,original)
  var correct_order: Array=[]
  for step in original.steps_ar:correct_order.append(q.steps_ar.find(step))
  ck(a.step_picks==correct_order,"drag signal arranges the original steps")
  a.order_undo.pressed.emit();await process_frame;await process_frame
  ck(a.step_picks==Array(range(q.steps_ar.size())),"reset restores the initial order")
  await arrange_steps(a,q,original)
  a.order_submit.pressed.emit();b.order_submit.pressed.emit()
 elif mode=="memory":
  ck(a.memory_grid.visible and not a.answer_buttons[0].visible,"memory retains actual pair board")
  await solve_memory(a);await solve_memory(b)
 else:
  var correct: int=q.choices_ar.find(original.choices_ar[int(original.correct)])
  a.answer_buttons[correct].pressed.emit();b.answer_buttons[(correct+1)%q.choices_ar.size()].pressed.emit()
 ck(await until(func():return a.client.state.quiz.phase=="finished" and b.client.state.quiz.phase=="finished"),game+" shared final results")
 ck(a.client.state.scores==b.client.state.scores and a.client.state.scores[0]>0,game+" authoritative identical scores")
 var leader: int=0 if int(a.client.state.scores[0])>=int(a.client.state.scores[1]) else 1
 var boards_ready: bool=a.quiz_scoreboard.visible and b.quiz_scoreboard.visible and a.quiz_scoreboard.get_child_count()==2 and b.quiz_scoreboard.get_child_count()==2
 ck(boards_ready,game+" final standings visible to both players")
 if boards_ready:ck(int(a.quiz_scoreboard.get_child(0).get_meta("player_index"))==leader and int(b.quiz_scoreboard.get_child(0).get_meta("player_index"))==leader,game+" standings use the server score order")
 await snap(game+"-results")
 a.client.send_action("duel_leave");await create_timer(.1).timeout
 for ui in [a,b]:ui.client.close_transport();ui.queue_free()
 await process_frame
func run() -> void:
 create_timer(300).timeout.connect(func():print("MECHANICS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(folder);root.content_scale_size=Vector2i(420,900)
 var games: Array=["2","7","9","4","5","8"]
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--endpoint="):endpoint=arg.trim_prefix("--endpoint=")
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=");DirAccess.make_dir_recursive_absolute(folder)
  if arg.begins_with("--games="):games=Array(arg.trim_prefix("--games=").split(","))
 for index in range(games.size()):
  # Two fresh authenticated clients per game; respect the real 10 sessions/minute limit.
  if index>0:await create_timer(15).timeout
  await suite(str(games[index]))
 print("ORIGINAL_ALL_REAL_GODOT_UI_WS ",failures.is_empty()," ",failures)
 quit(0 if failures.is_empty() else 1)
