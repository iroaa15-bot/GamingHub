extends SceneTree
const Client = preload("res://scripts/photo_duel_extension_client.gd")
var failures := 0
var checks := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 print(("PASS " if ok else "FAIL ")+message)
 if not ok:failures+=1
func until(predicate: Callable,seconds: float=6.0) -> bool:
 var end:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:
  if predicate.call():return true
  await create_timer(.025).timeout
 return false
func make_client(endpoint: String) -> Node:
 var client:=Client.new()
 client.authenticate_local=true
 client.terms_accepted=true
 root.add_child(client)
 client.connect_endpoint(endpoint)
 return client
func run() -> void:
 create_timer(80).timeout.connect(func():print("FAIL secure integration timeout");quit(2))
 if not Engine.is_editor_hint() or root.has_node("DailyRounds") or root.has_node("LiveOps"):
  print("FAIL unsafe autoloads")
  quit(1)
  return
 var endpoint:=Client.endpoint_from_args()
 var a:=make_client(endpoint)
 var b:=make_client(endpoint)
 var c:=make_client(endpoint)
 var clients: Array=[a,b,c]
 for client in clients:check(await until(func():return not client.capabilities.is_empty()),"Godot HTTP authentication then WebSocket handshake")
 check(bool(a.capabilities.get("authenticated",false)) and bool(a.capabilities.get("voice",false)),"secure server advertises authenticated original-codec voice")
 a.create_room(3,0,2)
 await until(func():return not a.code.is_empty())
 b.join_room(a.code)
 c.join_room(a.code)
 check(await until(func():return bool(a.state.get("started",false))),"authenticated room setup for new security/media checks")
 var stolen: String=a.token
 var errors: int=c.error_count
 var foreign:=make_client(endpoint)
 await until(func():return not foreign.capabilities.is_empty())
 foreign.send_action("duel_resume",{"code":a.code,"token":stolen})
 check(await until(func():return foreign.error_count>0),"foreign authenticated subject cannot use a room token")
 for client in clients:client.send_action("duel_voice_state",{"enabled":true})
 check(await until(func():return a.state.get("voice",{}).get("peer_enabled",false) and b.state.get("voice",{}).get("local_enabled",false) and c.state.get("voice",{}).get("local_enabled",false)),"per-player voice consent acknowledged")
 await create_timer(.1).timeout
 var received: Array=[]
 c.event_received.connect(func(message: Dictionary):
  if message.get("type")=="duel_voice_audio":received.append(message)
 )
 var bytes:=PackedByteArray()
 bytes.resize(640)
 for index in range(0,640,2):bytes.encode_s16(index,1000)
 var epoch: int=int(a.state.voice.epoch)
 a.send_action("duel_voice_audio",{"pcm":Marshalls.raw_to_base64(bytes),"seq":1,"epoch":epoch})
 check(await until(func():return not received.is_empty()),"server forwards original 640-byte PCM frame to consenting recipient")
 if not received.is_empty():
  var decoded:=Marshalls.base64_to_raw(received[-1].pcm)
  check(decoded.size()==640 and decoded.decode_s16(0)==1000,"mixed output preserves original native PCM codec")
 c.send_action("duel_voice_state",{"enabled":false})
 await until(func():return not bool(c.state.voice.local_enabled))
 await create_timer(.05).timeout
 received.clear()
 a.send_action("duel_voice_audio",{"pcm":Marshalls.raw_to_base64(bytes),"seq":2,"epoch":int(a.state.voice.epoch)})
 await create_timer(.15).timeout
 check(received.is_empty(),"mute consent prevents audio delivery")
 var before: int=a.error_count
 a.send_action("duel_voice_audio",{"pcm":"invalid","seq":3,"epoch":int(a.state.voice.epoch)})
 check(await until(func():return a.error_count>before),"malformed audio frame rejected")
 var original_token: String=b.token
 b.close_transport()
 await until(func():return bool(a.state.get("paused",false)))
 b.resume_session()
 check(await until(func():return b.token!=original_token and not bool(a.state.get("paused",true))),"same authenticated identity reconnects and rotates room token")
 check(not bool(a.state.voice.local_enabled) and not bool(b.state.voice.local_enabled),"reconnect clears voice consent and stale media")
 var report: Array=[]
 a.event_received.connect(func(message: Dictionary):
  if message.get("type")=="duel_reported":report.append(message)
 )
 a.send_action("duel_report",{"target":b.player,"reason":"local acceptance report"})
 check(await until(func():return not report.is_empty()),"in-app report acknowledged by moderation store")
 a.send_action("duel_block",{"target":b.player})
 check(await until(func():return bool(a.state.get("closed",false))),"blocking ends contact in the active room")
 # Authenticated transport retains original ping/pong wire contract, without re-running old room tests.
 var legacy:=WebSocketPeer.new()
 legacy.handshake_headers=PackedStringArray(["Authorization: Bearer "+a._auth_token])
 legacy.connect_to_url(endpoint)
 var until_open:=Time.get_ticks_msec()+5000
 while legacy.get_ready_state()!=WebSocketPeer.STATE_OPEN and Time.get_ticks_msec()<until_open:
  legacy.poll()
  await process_frame
 legacy.send_text(JSON.stringify({"type":"ping","id":71}))
 var pong: Dictionary={}
 var until_reply:=Time.get_ticks_msec()+5000
 while Time.get_ticks_msec()<until_reply:
  legacy.poll()
  if legacy.get_available_packet_count()>0:
   pong=JSON.parse_string(legacy.get_packet().get_string_from_utf8())
   break
  await process_frame
 check(pong.get("type")=="pong" and int(pong.get("id",0))==71,"authenticated gateway preserves original protocol message shape")
 legacy.close()
 for client in clients+[foreign]:client.close_transport();client.queue_free()
 await process_frame
 await process_frame
 print("VOICE_DEVICE_BLOCKED; PUBLIC_WSS_BLOCKED; PCM_TRANSPORT_ONLY_NOT_HARDWARE_AUDIO")
 print("SECURE_CHECKS ",checks," FAILURES ",failures)
 print("SECURE_INTEGRATION_"+("PASS" if failures==0 else "FAIL"))
 quit(0 if failures==0 else 1)
