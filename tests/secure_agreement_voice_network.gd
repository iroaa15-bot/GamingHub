extends SceneTree
const Client=preload("res://scripts/photo_duel_extension_client.gd")
var peers=[]
var failures=[]
var received=0
var refreshed=false
func _initialize() -> void:call_deferred("run")
func ck(ok: bool,name: String) -> void:
 print("SECURE_CHECK ",name," ",ok)
 if not ok:failures.append(name)
func until(predicate: Callable) -> bool:
 var end=Time.get_ticks_msec()+6000
 while Time.get_ticks_msec()<end:
  if predicate.call():return true
  await create_timer(.02).timeout
 return false
func peer() -> Node:
 var c=Client.new();root.add_child(c);peers.append(c);c.authenticate_local=true;c.terms_accepted=true;c.connect_endpoint("ws://127.0.0.1:8883");return c
func accept(c: Node) -> void:c.send_action("duel_accept",{"config_revision":int(c.state.config_revision),"picture_difficulty":c.state.picture_difficulty})
func run() -> void:
 create_timer(45).timeout.connect(func():print("SECURE_AGREEMENT_TIMEOUT");quit(1))
 var a=peer();var b=peer()
 b.event_received.connect(func(msg):
  if msg.get("type")=="duel_voice_audio":received+=1)
 a.event_received.connect(func(msg):
  if msg.get("type")=="duel_session_refreshed":refreshed=true)
 ck(await until(func():return a.capabilities.get("room_agreement",false) and b.capabilities.get("voice",false)),"authenticated clients negotiate agreement and voice")
 a.create_room(2,30,1,{"picture_difficulty":"easy"})
 ck(await until(func():return a.state.get("room_agreement",false)),"secure agreed room create")
 b.join_room(a.code)
 ck(await until(func():return b.state.get("joined",0)==2 and a.state.get("joined",0)==2),"secure room membership")
 a.send_action("duel_propose",{"picture_category":"animals","primary_mode":"voice"})
 ck(await until(func():return b.state.get("primary_mode","")=="voice"),"voice mode proposal sync")
 a.send_action("duel_voice_state",{"enabled":true});b.send_action("duel_voice_state",{"enabled":true})
 ck(await until(func():return a.state.voice.local_enabled and a.state.voice.peer_enabled and b.state.voice.local_enabled and b.state.voice.peer_enabled),"mutual consent while waiting")
 var pcm=PackedByteArray();pcm.resize(640)
 a.send_action("duel_voice_audio",{"epoch":int(a.state.voice.epoch),"seq":1,"pcm":Marshalls.raw_to_base64(pcm)})
 ck(await until(func():return received>0),"existing mixer delivers PCM in waiting room (synthetic silence)")
 accept(a);accept(b)
 ck(await until(func():return a.state.confirmed.count(true)==2),"both accept voice configuration")
 a.send_action("duel_start")
 ck(await until(func():return b.state.started),"start after voice agreement")
 a.send_action("duel_voice_question")
 ck(await until(func():return b.state.pending is Dictionary and b.state.pending.get("mode")=="voice"),"voice question opens authorized yes no")
 b.send_action("duel_reply",{"answer":true})
 ck(await until(func():return a.state.current==1),"yes no synchronizes turn")
 b.send_action("duel_guess",{"guess":"اختبار"})
 await until(func():return a.state.pending is Dictionary and a.state.pending.get("kind")=="guess")
 a.send_action("duel_confirm",{"correct":true})
 ck(await until(func():return b.state.get("match_finished",false)),"match ends without destroying membership")
 ck(not a.code.is_empty() and not a.token.is_empty() and a.state.voice.available and not a.state.closed,"voice survives finished match")
 var before=received
 a.send_action("duel_voice_audio",{"epoch":int(a.state.voice.epoch),"seq":2,"pcm":Marshalls.raw_to_base64(pcm)})
 ck(await until(func():return received>before),"mixer delivers after match")
 await create_timer(1.1).timeout
 a._auth_expiry=Time.get_ticks_msec()+60000
 ck(await until(func():return refreshed),"automatic same-identity auth renewal")
 b.close_transport()
 ck(await until(func():return a.state.paused),"connection loss pauses voice")
 b.resume_session()
 ck(await until(func():return not a.state.paused and not b.state.get("paused",true) and not b.capabilities.is_empty()),"authenticated finished-room reconnect")
 ck(not a.state.voice.local_enabled and not b.state.voice.local_enabled,"fresh consent required after reconnect")
 a.send_action("duel_voice_state",{"enabled":true});b.send_action("duel_voice_state",{"enabled":true})
 ck(await until(func():return a.state.voice.peer_enabled and b.state.voice.peer_enabled),"renewed consent")
 before=received
 a.send_action("duel_voice_audio",{"epoch":int(a.state.voice.epoch),"seq":1,"pcm":Marshalls.raw_to_base64(pcm)})
 ck(await until(func():return received>before),"new epoch PCM resumes")
 a.send_action("duel_leave")
 ck(await until(func():return b.state.get("closed",false)),"exit closes voice room cleanly")
 print("SECURE_AGREEMENT_VOICE_REAL_GODOT ",failures.is_empty()," synthetic transport, not acoustic Android PASS ",failures)
 for c in peers:c.close_transport();c.queue_free()
 await process_frame;quit(0 if failures.is_empty() else 1)
