extends SceneTree
const Client=preload("res://scripts/photo_duel_extension_client.gd")
var nodes=[]
var failures=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, name: String) -> void:
 print("CHECK ",name," ",ok)
 if not ok: failures.append(name)
func until(predicate: Callable) -> bool:
 var end=Time.get_ticks_msec()+5000
 while Time.get_ticks_msec()<end:
  if predicate.call(): return true
  await create_timer(.02).timeout
 return false
func peer() -> Node:
 var c=Client.new();root.add_child(c);nodes.append(c);c.connect_endpoint("ws://127.0.0.1:8882");return c
func accept(c: Node) -> void:
 c.send_action("duel_accept",{"config_revision":int(c.state.get("config_revision",-1)),"picture_difficulty":c.state.get("picture_difficulty","")})
func rejected(c: Node, action: String, fields: Dictionary={}) -> bool:
 var count: int=c.error_count;c.send_action(action,fields)
 return await until(func(): return c.error_count>count)
func run() -> void:
 create_timer(60).timeout.connect(func(): print("AGREEMENT_TIMEOUT");quit(1))
 var a=peer();var b=peer()
 check(await until(func(): return a.capabilities.get("room_agreement",false) and b.capabilities.get("room_agreement",false)),"capability")
 a.create_room(2,30,10,{"picture_difficulty":"easy"})
 check(await until(func():return a.state.get("room_agreement",false)),"opt in")
 b.join_room(a.code)
 check(await until(func():return a.state.get("joined",0)==2 and b.state.get("joined",0)==2),"two joined")
 check(not a.state.started and a.state.opponents.is_empty(),"no autostart or lobby photo disclosure")
 check(await rejected(a,"duel_start"),"start requires all confirmations")
 check(await rejected(b,"duel_propose",{"picture_category":"animals","primary_mode":"text"}),"host only")
 check(await rejected(a,"duel_propose",{"picture_category":"animals","primary_mode":"voice"}),"no fake voice service")
 accept(a);accept(b)
 check(await until(func():return a.state.confirmed.count(true)==2),"both confirm")
 a.send_action("duel_propose",{"picture_category":"animals","primary_mode":"text"})
 check(await until(func():return b.state.get("primary_mode","")=="text"),"configuration sync")
 check(a.state.confirmed.count(true)==0 and b.state.picture_difficulty=="easy","change resets confirmations and preserves difficulty")
 check(await rejected(b,"duel_accept",{"config_revision":1,"picture_difficulty":"hard"}),"stale or different difficulty rejected")
 accept(a);accept(b)
 check(await until(func():return a.state.confirmed.count(true)==2),"reconfirmed")
 a.send_action("duel_start")
 check(await until(func():return b.state.started),"server validated start")
 check(await rejected(a,"duel_preset",{"question_id":"living"}),"wrong mode rejected")
 a.send_action("duel_question",{"text":"هل هو حيوان؟"})
 check(await until(func():return b.state.pending is Dictionary and b.state.pending.get("kind")=="question"),"text question sync")
 check(await rejected(a,"duel_text_reply",{"text":"نعم"}),"turn authorized response")
 b.send_action("duel_text_reply",{"text":"نعم، حيوان"})
 check(await until(func():return a.state.current==1),"text reply switches turn")
 check(a.state.history.any(func(e):return e.get("answer_text","")=="نعم، حيوان"),"free text answer sync")
 b.send_action("duel_guess",{"guess":"اختبار التخمين"})
 check(await until(func():return a.state.pending is Dictionary and a.state.pending.get("kind")=="guess"),"guess synchronization")
 a.send_action("duel_confirm",{"correct":true})
 check(await until(func():return b.state.scores[1]==1 and a.state.current==0),"score and filtered replacement sync")
 b.close_transport()
 check(await until(func():return a.state.paused),"pause on connection loss")
 b.resume_session()
 check(await until(func():return not a.state.paused and not b.state.paused and not b.capabilities.is_empty()),"real client resume")
 a.send_action("duel_leave")
 await create_timer(.1).timeout
 # New six-player agreement flow, distinct from previously passed legacy protocol tests.
 var six=[]
 for i in range(6):six.append(peer())
 check(await until(func():return six.all(func(c):return not c.capabilities.is_empty())),"six protocol ready")
 six[0].create_room(6,0,10,{"picture_difficulty":"medium"})
 check(await until(func():return six[0].state.get("room_agreement",false)),"six room")
 for i in range(1,6):six[i].join_room(six[0].code)
 check(await until(func():return six.all(func(c):return c.state.get("joined",0)==6)),"six joined without autostart")
 check(not six[0].state.started,"six waiting for agreement")
 check(await rejected(six[0],"duel_propose",{"picture_category":"science","primary_mode":"tap"}),"insufficient real category rejected")
 for c in six:accept(c)
 check(await until(func():return six[0].state.confirmed.count(true)==6),"six confirm")
 six[0].send_action("duel_start")
 check(await until(func():return six.all(func(c):return c.state.started)),"six agreed start")
 var q: String=six[0].state.preset_questions[0]
 six[0].send_action("duel_preset",{"question_id":q})
 check(await until(func():return six[1].state.pending is Dictionary),"tap question sync")
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/guess_picture_302/catalog.json"))
 var actual=false
 for item in data.items:
  if item.image==six[1].state.opponents.filter(func(o):return o.player==0)[0].image:actual=item.facts[q]
 six[1].send_action("duel_reply",{"answer":actual})
 check(await until(func():return six[0].state.current==1),"tap authorized yes no")
 # Backward compatibility: the same endpoint still supports the unchanged default flow.
 var old_a=peer();var old_b=peer()
 await until(func():return not old_a.capabilities.is_empty() and not old_b.capabilities.is_empty())
 old_a.send_action("duel_create",{"players":2,"timer":30,"target":10})
 await until(func():return not old_a.code.is_empty())
 old_b.join_room(old_a.code)
 check(await until(func():return old_a.state.get("started",false)),"unmodified payload autostarts compatibly")
 print("ROOM_AGREEMENT_REAL_GODOT_WS ",failures.is_empty()," failures=",failures)
 for c in nodes:c.close_transport();c.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
