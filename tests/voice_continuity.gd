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
 snapshot.primary_mode="text";adapter._state(snapshot)
 var text_stopped: bool=not bridge.active and not adapter.requested
 adapter.queue_free();connection.queue_free();bridge.queue_free();await process_frame
 print("VOICE_CONTINUITY continuous=",continuous," text_stopped=",text_stopped)
 quit(0 if continuous and text_stopped else 1)
