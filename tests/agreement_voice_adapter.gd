extends SceneTree
class Connection extends Node:
 signal state_changed(value: Dictionary)
 signal event_received(value: Dictionary)
 signal connection_changed(ready: bool)
 var capabilities={"voice":true}
 var code="ROOM"
 var state={}
 var socket=WebSocketPeer.new()
 var sent=[]
 func send_action(kind: String,fields: Dictionary={}) -> Error:sent.append([kind,fields]);return OK
class Bridge extends Node:
 signal permission_ready(granted: bool)
 var granted=true
 var active=false
 var received=0
 func is_available() -> bool:return true
 func request_permission() -> void:permission_ready.emit(granted)
 func set_consent(local: bool,peer: bool) -> void:active=local and peer
 func stop_voice() -> void:active=false
 func receive_pcm(_pcm: String,_seq: int) -> void:received+=1
var errors=[]
func ck(ok: bool,name: String) -> void:
 print("VOICE_CHECK ",name," ",ok)
 if not ok:errors.append(name)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var c=Connection.new();root.add_child(c)
 var a=load("res://scripts/photo_duel_voice_adapter.gd").new();root.add_child(a);a.attach(c)
 var old=a.bridge;var b=Bridge.new();root.add_child(b);a.bridge=b;old.queue_free()
 b.permission_ready.connect(a._permission)
 b.granted=false;a.enable(true)
 ck(not a.requested and c.sent.is_empty() and not b.active,"permission denial blocks native and consent")
 b.granted=true;a.enable(true)
 ck(a.requested and not b.active and c.sent.size()==1,"permission is not peer consent")
 var state={"code":"ROOM","room_agreement":true,"primary_mode":"voice","started":false,"voice":{"available":true,"epoch":1,"local_enabled":true,"peer_enabled":true}}
 a._state(state);ck(b.active,"waiting room voice")
 a.set_muted(true);a._outgoing("private fixture")
 var payload=Marshalls.base64_to_raw(c.sent.back()[1].pcm)
 ck(payload.size()==640 and payload.count(0)==640 and b.active,"mute sends silence without disconnecting")
 a._event({"type":"duel_voice_audio","epoch":1,"seq":1,"pcm":"fixture"})
 ck(b.received==1,"incoming remains active while muted")
 state.started=true;state.match_finished=true;a._state(state)
 ck(b.active and a.requested,"finished match retains membership voice")
 c.capabilities={};c.connection_changed.emit(false)
 ck(not b.active and a.requested,"loss stops native and retains room intent")
 c.capabilities={"voice":true};state.voice={"available":true,"epoch":2,"local_enabled":false,"peer_enabled":false};a._state(state)
 ck(not b.active and c.sent.back()[0]=="duel_voice_state","resume requests fresh server consent")
 state.voice.local_enabled=true;state.voice.peer_enabled=true;a._state(state)
 ck(b.active and a.muted,"fresh ack resumes with mute retained")
 a.set_muted(false);a._outgoing("unmuted fixture")
 ck(c.sent.back()[1].pcm=="unmuted fixture","unmute uses original outgoing frame")
 c.connection_changed.emit(false);a.enable(false);state.voice.local_enabled=false;a._state(state)
 ck(not b.active and not a.requested,"manual stop cancels reconnect intent")
 a.enable(true);state.voice.local_enabled=true;a._state(state);c.code="OTHER";state.code="OTHER";a._state(state)
 ck(not b.active and not a.requested,"different room never inherits microphone consent")
 a._failure("audio_focus_lost")
 ck(a.last_failure=="audio_focus_lost" and not a.requested,"interruption records retry status")
 a.enable(true);ck(a.last_failure.is_empty(),"explicit retry clears stale interruption")
 a.enable(false)
 a.queue_free();c.queue_free();b.queue_free();await process_frame
 print("AGREEMENT_VOICE_ADAPTER ",errors.is_empty()," fake JNI boundary only")
 quit(0 if errors.is_empty() else 1)
