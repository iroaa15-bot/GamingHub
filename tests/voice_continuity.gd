extends SceneTree
const Fixture=preload("res://tests/agreement_voice_adapter.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.get_node("PublishedContent").busy=true
 root.get_node("RoomAudioPolicy").set_music_enabled(false)
 root.get_node("RoomAudioPolicy").set_effects_enabled(false)
 var connection=Fixture.Connection.new();root.add_child(connection)
 var adapter=load("res://scripts/photo_duel_voice_adapter.gd").new();root.add_child(adapter);adapter.attach(connection)
 var original=adapter.bridge
 var bridge=Fixture.Bridge.new();root.add_child(bridge);adapter.bridge=bridge;original.queue_free()
 adapter.requested=true;adapter._permission_granted=true;adapter._room=connection.code
 var snapshot={"code":"ROOM","room_agreement":true,"primary_mode":"voice","started":false,"voice":{"available":true,"epoch":1,"local_enabled":true,"peer_enabled":true}}
 adapter._state(snapshot)
 var initial_stops: int=bridge.stops
 var continuous: bool=true
 for mode in ["voice","mixed"]:
  snapshot.primary_mode=mode
  for round_index in range(1,21):
   snapshot.started=true;snapshot.round=round_index;snapshot.current=round_index%2;snapshot.scores=[round_index,0]
   adapter._state(snapshot)
   continuous=continuous and bridge.active and adapter.requested and bridge.stops==initial_stops
 adapter._event({"type":"duel_error","scope":"voice","message":"Request rate limit"})
 adapter._event({"type":"duel_error","scope":"voice","message":"Stale audio frame"})
 adapter._event({"type":"duel_error","scope":"voice","message":"Voice consent or epoch mismatch"})
 continuous=continuous and bridge.active and adapter.requested and adapter._congestion_events==3
 snapshot.voice.peer_enabled=false;adapter._state(snapshot)
 adapter._event({"type":"duel_error","scope":"voice","message":"Voice consent or epoch mismatch"})
 var withdrawn: bool=not bridge.active and adapter.requested
 snapshot.voice.peer_enabled=true;adapter._state(snapshot)
 var admitted: int=0
 for index in range(100):
  if adapter._admit_frame(0):admitted+=1
 var bounded: bool=admitted==55 and not adapter._admit_frame(500) and adapter._admit_frame(1001)
 snapshot.primary_mode="text";adapter._state(snapshot)
 var text_stopped: bool=not bridge.active and not adapter.requested
 adapter.queue_free();connection.queue_free();bridge.queue_free();await process_frame
 print("VOICE_CONTINUITY continuous=",continuous," text_stopped=",text_stopped," bounded=",bounded," peer_withdrawal_stops_native=",withdrawn)
 quit(0 if continuous and text_stopped and bounded and withdrawn else 1)
