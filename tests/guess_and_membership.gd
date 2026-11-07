extends SceneTree
class Capture:
 extends Node
 var state={"primary_mode":"text"}
 var code: String=""
 var sent: Array=[]
 func send_action(kind: String,fields: Dictionary={}) -> Error:
  sent.append([kind,fields]);return OK
class Recovery:
 extends "res://scripts/photo_duel_extension_client.gd"
 var resumes:=0
 func resume_session() -> Error:
  resumes+=1;return OK
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.get_node("PublishedContent").busy=true
 root.get_node("RoomAudioPolicy").set_music_enabled(false)
 root.get_node("RoomAudioPolicy").set_effects_enabled(false)
 var ui=load("res://scripts/photo_duel_extension_ui.gd").new();root.add_child(ui)
 var client:=Capture.new();root.add_child(client)
 ui.client.queue_free();ui.client=client
 ui.question_field.text="   ";ui._submit_guess()
 assert(client.sent.is_empty())
 ui.question_field.text="Lion";ui._submit_guess()
 assert(client.sent.size()==1 and client.sent.back()[1].guess=="Lion")
 client.state.primary_mode="mixed";ui.question_field.text="Apple";ui.guess_field.text="wrong old field";ui._submit_guess()
 assert(client.sent.back()[1].guess=="Apple")
 client.state.primary_mode="voice";ui._submit_guess()
 assert(client.sent.size()==2)
 ui.voice_adapter.requested=true;ui.voice_adapter.bridge.active=true;ui._submit_guess()
 assert(client.sent.size()==3 and not client.sent.back()[1].guess.is_empty())
 assert(not ui._connection_message("Invalid text").contains("الاتصال"))
 var recovery:=Recovery.new();root.add_child(recovery)
 recovery.code="123456";recovery.token="private-test-room-token";recovery.capabilities={"voice":true}
 recovery._received({"type":"duel_error","scope":"voice","message":"Not in a room"})
 recovery._received({"type":"duel_error","scope":"voice","message":"Not in a room"})
 assert(recovery.capabilities.is_empty())
 await process_frame
 assert(recovery.resumes==1 and recovery.code=="123456" and recovery.token=="private-test-room-token")
 recovery._received({"type":"duel_resumed","code":"123456","token":"private-test-room-token","player":0})
 assert(not recovery._membership_recovery_scheduled)
 ui.queue_free();client.queue_free();recovery.queue_free();await process_frame
 print("GUESS_AND_MEMBERSHIP_PASS blank validation, spoken confirmation, one identity-preserving recovery")
 quit(0)
