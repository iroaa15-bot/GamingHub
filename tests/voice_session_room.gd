extends SceneTree
class Session extends "res://scripts/multiplayer.gd":
 var sent: Array=[]
 func _send(message: Dictionary) -> void: sent.append(message.duplicate(true))
class Bridge extends Node:
 signal permission_ready(granted: bool)
 var active := false
 var consents: Array=[]
 func is_available() -> bool: return true
 func request_permission() -> void: permission_ready.emit(true)
 func set_consent(local: bool,peer: bool) -> void:
  consents.append([local,peer]);active=local and peer
 func stop_voice() -> void: active=false
func _initialize() -> void: call_deferred("run")
func ack(room: Node,epoch: int) -> void:
 room._apply_voice_state({"type":"voice_state_ack","protocol":2,"request_id":room.voice_request_id,"epoch":epoch,"local_enabled":true,"peer_enabled":true})
func run() -> void:
 var room=Session.new();root.add_child(room)
 var original=room.android_voice_bridge
 var bridge=Bridge.new();root.add_child(bridge)
 room.android_voice_bridge=bridge
 bridge.permission_ready.connect(room._on_voice_permission)
 original.queue_free()
 room.connected=true;room.room_code="VOICE_UI_FIXTURE";room.player_index=0;room.finished=false
 room.set_voice_opt_in(true)
 var valid=room.sent.size()==1 and not bridge.active
 ack(room,1)
 valid=valid and bridge.active and room._voice_room_ready()
 room._toggle_voice_mute()
 var silence=Marshalls.base64_to_raw(room._voice_payload("not-real-audio"))
 valid=valid and room.voice_muted and bridge.active and silence.size()==640 and silence.count(0)==640
 room._reset_voice_on_connection_loss(true)
 valid=valid and not bridge.active and room._voice_resume_intent
 room.reconnecting=true
 var sent_count=room.sent.size()
 room._resume_voice_after_sync()
 valid=valid and room.sent.size()==sent_count and not bridge.active
 room.reconnecting=false
 room._resume_voice_after_sync()
 valid=valid and room.sent.size()==sent_count+1 and not bridge.active and room.voice_muted
 ack(room,2)
 valid=valid and bridge.active and room.voice_muted
 room._toggle_voice_mute()
 valid=valid and room._voice_payload("fixture")=="fixture" and bridge.active
 room._reset_voice_on_connection_loss(true)
 room.set_voice_opt_in(false)
 sent_count=room.sent.size()
 room._resume_voice_after_sync()
 valid=valid and not room._voice_resume_intent and room.sent.size()==sent_count and not bridge.active
 room.set_voice_opt_in(true);ack(room,3)
 room._reset_voice_on_connection_loss(true)
 room.room_code="DIFFERENT_ROOM"
 room._resume_voice_after_sync()
 valid=valid and not room._voice_resume_intent and not bridge.active
 room.finished=true;room.voice_room_membership_supported=false
 valid=valid and not room._voice_room_ready()
 room.voice_room_membership_supported=true
 valid=valid and room._voice_room_ready()
 room._reset_voice_on_connection_loss()
 valid=valid and not room._voice_resume_intent and not bridge.active
 print("VOICE_ROOM_SESSION ",valid," — mute/privacy/consent/reconnect policy; not real-device soak or post-match server support")
 room.queue_free();bridge.queue_free();await process_frame
 quit(0 if valid else 1)
