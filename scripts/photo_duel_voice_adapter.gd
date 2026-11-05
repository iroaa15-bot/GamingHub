extends Node
## Isolated adapter: original native bridge/API and audio engine are unchanged.
signal changed
signal unavailable(reason: String)
var client: Node
var bridge: Node
var requested := false
var muted := false
var _permission_granted := false
var _sent_opt_in := false
var _room := ""
var epoch := -1
var sequence := 0
var last_status := ""
var last_failure := ""
var _health_elapsed := 0.0
var _handling_failure := false
func attach(connection: Node) -> void:
 client = connection
 bridge = load("res://scripts/android_voice_integration_bridge.gd").new()
 bridge.outgoing_pcm.connect(_outgoing)
 bridge.permission_ready.connect(_permission)
 bridge.voice_unavailable.connect(_failure)
 bridge.status_changed.connect(func(_state: String, details: String): last_status=details; changed.emit())
 add_child(bridge)
 client.state_changed.connect(_state)
 client.event_received.connect(_event)
 client.connection_changed.connect(func(ready: bool):
  if not ready: _stop(true)
 )
func is_available() -> bool:
 return is_instance_valid(bridge) and bridge.is_available()
func enable(value: bool) -> void:
 last_failure=""
 if not value:
  requested=false
  _sent_opt_in=false
  _permission_granted=false
  if not client.capabilities.is_empty(): client.send_action("duel_voice_state",{"enabled":false})
  bridge.set_consent(false,false)
  changed.emit()
  return
 if not is_available() or not bool(client.capabilities.get("voice",false)):
  unavailable.emit("Native Android voice is unavailable")
  return
 requested=true
 _room=client.code
 _sent_opt_in=false
 bridge.request_permission()
func _permission(granted: bool) -> void:
 if not requested: return
 if not granted:
  requested=false
  unavailable.emit("Microphone permission denied")
 else:
  _permission_granted=true
  _sent_opt_in=client.send_action("duel_voice_state",{"enabled":true})==OK
 changed.emit()
func _state(snapshot: Dictionary) -> void:
 var voice: Dictionary = snapshot.get("voice",{})
 var same_room: bool=not _room.is_empty() and str(snapshot.get("code",client.code))==_room and client.code==_room
 if not same_room and requested:
  _stop()
  return
 if bool(snapshot.get("closed",false)) or (snapshot.get("room_agreement",false) and snapshot.get("primary_mode","")!="voice"):
  _stop()
  return
 var ready: bool=bool(voice.get("available",false)) and not client.capabilities.is_empty() and not bool(snapshot.get("paused",false))
 var next_epoch: int=int(voice.get("epoch",-1))
 if next_epoch!=epoch:
  bridge.stop_voice()
  sequence=0
  epoch=next_epoch
 if not ready:
  _sent_opt_in=false
  bridge.set_consent(false,false)
 elif requested and _permission_granted and not bool(voice.get("local_enabled",false)) and not _sent_opt_in:
  _sent_opt_in=client.send_action("duel_voice_state",{"enabled":true})==OK
  bridge.set_consent(false,false)
 else:
  bridge.set_consent(requested and _permission_granted and ready and bool(voice.get("local_enabled",false)),bool(voice.get("peer_enabled",false)))
 changed.emit()

func set_muted(value: bool) -> void:
 muted=value
 changed.emit()

func _outgoing(pcm: String) -> void:
 if not requested or epoch<0 or not bridge.active: return
 if client.socket.get_current_outbound_buffered_amount()>32768: return
 sequence+=1
 var payload: String=pcm
 if muted:
  var silence := PackedByteArray()
  silence.resize(640)
  payload=Marshalls.raw_to_base64(silence)
 client.send_action("duel_voice_audio",{"pcm":payload,"seq":sequence,"epoch":epoch})
func _event(message: Dictionary) -> void:
 if message.get("type")=="duel_error" and message.get("scope")=="voice":
  _failure(str(message.get("message","Voice transport failed")))
  return
 if message.get("type")=="duel_voice_audio" and requested and int(message.get("epoch",-2))==epoch:
  bridge.receive_pcm(str(message.get("pcm","")),int(message.get("seq",-1)))
func _stop(preserve_intent: bool=false) -> void:
 if not preserve_intent:
  requested=false
  _permission_granted=false
  _room=""
 _sent_opt_in=false
 epoch=-1
 sequence=0
 if is_instance_valid(bridge): bridge.set_consent(false,false)
 changed.emit()
func _exit_tree() -> void:
 _stop()

func _failure(reason: String) -> void:
 if _handling_failure: return
 _handling_failure=true
 var was_requested := requested
 requested=false
 _sent_opt_in=false
 _permission_granted=false
 last_status=reason
 last_failure=reason
 if OS.is_debug_build():print("GH_VOICE_FAILURE ",reason)
 if was_requested and is_instance_valid(client) and not client.capabilities.is_empty() and not client.code.is_empty() and not bool(client.state.get("paused",false)) and not bool(client.state.get("closed",false)):
  client.send_action("duel_voice_state",{"enabled":false})
 if is_instance_valid(bridge): bridge.set_consent(false,false)
 unavailable.emit(reason)
 changed.emit()
 _handling_failure=false

# Diagnostic counters only in test builds; never PCM, speech, tokens or room codes.
func _process(delta: float) -> void:
 if not OS.is_debug_build() or not requested or not is_instance_valid(bridge):return
 _health_elapsed+=delta
 if _health_elapsed<5.0:return
 _health_elapsed=0.0
 if bridge.has_method("voice_health_snapshot"):print("GH_VOICE_HEALTH ",JSON.stringify(bridge.voice_health_snapshot()))
