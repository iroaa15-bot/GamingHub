extends SceneTree
var failed:=false
func _initialize():call_deferred("run")
func ck(value: bool,title: String):
 print("AUDIO_POLICY ",title," ",value)
 if not value:failed=true
func run():
 create_timer(10).timeout.connect(func():quit(2))
 ck(root.get_node_or_null("RoomAudioPolicy")!=null and root.get_node("RoomAudioPolicy").is_node_ready(),"autoload ready before scene setup")
 ck(load("res://scripts/main.gd").can_instantiate(),"main parses with audio routes")
 ck(load("res://scripts/multiplayer.gd").can_instantiate(),"classic parses with membership lock")
 ck(load("res://scripts/shared_quiz_ui.gd").can_instantiate(),"shared quiz parses with game bus")
 var policy=load("res://scripts/room_audio_policy.gd").acquire(self)
 var music=AudioStreamPlayer.new();root.add_child(music)
 music.stream=load("res://assets/audio/bell.wav");policy.register_music(music);music.play()
 ck(music.playing,"fixture playing outside room")
 var client=load("res://scripts/photo_duel_extension_client.gd").new();root.add_child(client)
 client.capabilities={"voice":true}
 client._received({"type":"duel_joined","code":"123456","token":"fixture","player":0})
 await create_timer(.5).timeout
 ck(not policy.music_blocked() and music.playing and AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))<-18,"room music ducks for voice")
 for snapshot in [{"paused":false,"started":true},{"paused":true},{"match_finished":true},{"voice":{"local_enabled":false}}]:
  client._received({"type":"duel_state","code":"123456"}.merged(snapshot))
  ck(music.playing and AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))<-18,"ducking survives match/mute/pause")
 client.close_transport();ck(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))<-18,"transport loss keeps ducking")
 policy.set_music_enabled(false);client.queue_free();await process_frame
 ck(music.stream_paused,"disabled music stays paused after exit")
 policy.set_music_enabled(true);ck(music.playing,"enabled music resumes after full exit")
 var second=Node.new();root.add_child(second);policy.membership(second,true)
 await create_timer(.2).timeout
 policy.set_music_enabled(true);ck(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))<-18,"settings preserve room ducking")
 policy.membership(second,false);ck(music.playing,"explicit membership release resumes")
 for bus in ["Music","UI SFX","Game SFX","Voice Chat"]:ck(AudioServer.get_bus_index(bus)>=0,"separate bus "+bus)
 second.queue_free();music.queue_free();await process_frame
 quit(1 if failed else 0)

