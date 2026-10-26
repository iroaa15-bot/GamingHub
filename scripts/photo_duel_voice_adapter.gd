extends Node
## Isolated adapter: original native bridge/API and audio engine are unchanged.
signal changed
signal unavailable(reason: String)
var client: Node
var bridge: Node
var requested := false
var epoch := -1
var sequence := 0
var last_status := ""
func attach(connection: Node) -> void:
 client = connection
 bridge = load("res://scripts/android_voice_bridge.gd").new()
 bridge.outgoing_pcm.connect(_outgoing)
 bridge.permission_ready.connect(_permission)
 bridge.voice_unavailable.connect(_failure)
 bridge.status_changed.connect(func(_state: String, details: String): last_status=details; changed.emit())
 add_child(bridge)
 client.state_changed.connect(_state)
 client.event_received.connect(_event)
 client.connection_changed.connect(func(ready: bool):
  if not ready: _stop()
 )
func is_available() -> bool:
 return is_instance_valid(bridge) and bridge.is_available()
func enable(value: bool) -> void:
 if not value:
  requested=false
  if not client.capabilities.is_empty(): client.send_action("duel_voice_state",{"enabled":false})
  bridge.set_consent(false,false)
  changed.emit()
  return
 if not is_available() or not bool(client.capabilities.get("voice",false)):
  unavailable.emit("Native Android voice is unavailable")
  return
 requested=true
 bridge.request_permission()
func _permission(granted: bool) -> void:
 if not requested: return
 if not granted:
  requested=false
  unavailable.emit("Microphone permission denied")
 else: client.send_action("duel_voice_state",{"enabled":true})
 changed.emit()
func _state(snapshot: Dictionary) -> void:
 var voice: Dictionary = snapshot.get("voice",{})
 var ready: bool = bool(voice.get("available",false)) and not client.capabilities.is_empty()
 var next_epoch: int = int(voice.get("epoch",-1))
 if next_epoch != epoch:
  bridge.stop_voice()
  sequence=0
  epoch=next_epoch
 if not bool(voice.get("local_enabled",false)) or not ready: requested=false
 bridge.set_consent(requested and ready and bool(voice.get("local_enabled",false)),bool(voice.get("peer_enabled",false)))
 changed.emit()
func _outgoing(pcm: String) -> void:
 if not requested or epoch<0 or not bridge.active: return
 if client.socket.get_current_outbound_buffered_amount()>32768: return
 sequence+=1
 client.send_action("duel_voice_audio",{"pcm":pcm,"seq":sequence,"epoch":epoch})
func _event(message: Dictionary) -> void:
 if message.get("type")=="duel_error" and message.get("scope")=="voice":
  _failure(str(message.get("message","Voice transport failed")))
  return
 if message.get("type")=="duel_voice_audio" and requested and int(message.get("epoch",-2))==epoch:
  bridge.receive_pcm(str(message.get("pcm","")),int(message.get("seq",-1)))
func _stop() -> void:
 requested=false
 epoch=-1
 sequence=0
 if is_instance_valid(bridge): bridge.set_consent(false,false)
 changed.emit()
func _exit_tree() -> void:
 _stop()

func _failure(reason: String) -> void:
 var was_requested := requested
 requested=false
 last_status=reason
 if was_requested and is_instance_valid(client) and not client.capabilities.is_empty() and not client.code.is_empty() and bool(client.state.get("started",false)) and not bool(client.state.get("paused",false)) and not bool(client.state.get("closed",false)):
  client.send_action("duel_voice_state",{"enabled":false})
 if is_instance_valid(bridge): bridge.set_consent(false,false)
 unavailable.emit(reason)
 changed.emit()
