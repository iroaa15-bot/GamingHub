extends SceneTree
var failures=[]
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
func suite(game: String) -> void:
 var script=load("res://scripts/shared_quiz_ui.gd");script.selected_game=game
 var a=script.new();root.add_child(a);a.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var b=script.new();root.add_child(b);b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);b.hide()
 a.endpoint_field.text="ws://127.0.0.1:8889";a.terms.button_pressed=true;a.target_field.value=1;a._request_room_action("create")
 if not await until(func():return not a.client.code.is_empty()):ck(false,game+" create: "+a.status.text);quit(1);return
 b.endpoint_field.text="ws://127.0.0.1:8889";b.terms.button_pressed=true;b.code_field.text=a.client.code;b._request_room_action("join")
 ck(await until(func():return a.client.state.get("joined",0)==2 and b.client.state.get("joined",0)==2),game+" real UI join")
 if game=="8":
  a.client.send_action("duel_quiz_propose",{"category":"Place","primary_mode":"text"})
  await until(func():return b.client.state.picture_category=="Place")
 a._accept_configuration();b._accept_configuration()
 await until(func():return a.client.state.confirmed.count(true)==2)
 a.client.send_action("duel_start")
 ck(await until(func():return a.quiz_panel.visible and b.quiz_panel.visible),game+" actual controls visible")
 ck(a.client.state.quiz.question==b.client.state.quiz.question,game+" same question payload")
 await create_timer(1.7).timeout
 var q: Dictionary=a.client.state.quiz.question
 var mode: String=q.get("mode","choice")
 await snap(game+"-"+mode)
 var original: Dictionary={}
 if game!="8":
  var bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
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
  for step in original.steps_ar:
   a.step_controls[q.steps_ar.find(step)].pressed.emit();await process_frame
  print("ORDER_PICKS_BEFORE ",a.step_picks," expected ",original.steps_ar.size()," undo_disabled ",a.order_undo.disabled)
  a.order_undo.pressed.emit();await process_frame;print("ORDER_PICKS_AFTER ",a.step_picks);ck(a.step_picks.size()==original.steps_ar.size()-1,"order undo")
  a.step_controls[q.steps_ar.find(original.steps_ar.back())].pressed.emit();await process_frame;a.order_submit.pressed.emit()
  for i in range(q.steps_ar.size()):b.step_controls[i].pressed.emit()
  b.order_submit.pressed.emit()
 elif mode=="memory":
  ck(a.memory_grid.visible and not a.answer_buttons[0].visible,"memory retains actual pair board")
  await solve_memory(a);await solve_memory(b)
 else:
  var correct: int=q.choices_ar.find(original.choices_ar[int(original.correct)])
  a.answer_buttons[correct].pressed.emit();b.answer_buttons[(correct+1)%q.choices_ar.size()].pressed.emit()
 ck(await until(func():return a.client.state.quiz.phase=="finished" and b.client.state.quiz.phase=="finished"),game+" shared final results")
 ck(a.client.state.scores==b.client.state.scores and a.client.state.scores[0]>0,game+" authoritative identical scores")
 await snap(game+"-results")
 a.client.send_action("duel_leave");await create_timer(.1).timeout
 for ui in [a,b]:ui.client.close_transport();ui.queue_free()
 await process_frame
func run() -> void:
 create_timer(160).timeout.connect(func():print("MECHANICS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(folder);root.content_scale_size=Vector2i(420,900)
 var games: Array=["2","7","9","4","5","8"]
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--games="):games=Array(arg.trim_prefix("--games=").split(","))
 for game in games:await suite(str(game))
 print("ORIGINAL_ALL_REAL_GODOT_UI_WS ",failures.is_empty()," ",failures)
 quit(0 if failures.is_empty() else 1)
