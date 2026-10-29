extends SceneTree
var failed:=false
func _initialize():call_deferred("run")
func ck(ok: bool,message: String):
 print("REAL_AUDIO ",message," ",ok)
 if not ok:failed=true
func run():
 create_timer(18).timeout.connect(func():quit(2))
 var policy=load("res://scripts/room_audio_policy.gd").acquire(self)
 policy.set_music_enabled(true);policy.set_effects_enabled(true)
 await create_timer(.5).timeout
 ck(policy.menu_player.playing and policy.menu_player.stream.get_length()>19.9,"real menu loaded and playing")
 ck(policy.menu_player.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and policy.menu_player.stream.loop_end==441000,"20s forward loop bounds")
 policy.menu_player.seek(19.8);await create_timer(.6).timeout
 ck(policy.menu_player.playing and policy.menu_player.get_playback_position()<2.0,"actual playback loops past end")
 var meter=AudioEffectCapture.new();var bus=AudioServer.get_bus_index("Music");AudioServer.add_bus_effect(bus,meter)
 await create_timer(.25).timeout
 var signal_data=meter.get_buffer(meter.get_frames_available());var peak: float=0
 for frame in signal_data:peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
 ck(peak>.0001,"Music bus produces nonzero PCM")
 var client=load("res://scripts/photo_duel_extension_client.gd").new();root.add_child(client);client.capabilities={"voice":true}
 client._received({"type":"duel_joined","code":"123456","token":"test","player":0})
 await create_timer(.5).timeout
 ck(not policy.menu_player.playing and AudioServer.is_bus_mute(bus),"real menu completely stops on membership")
 client.close_transport();policy.set_music_enabled(true)
 ck(not policy.menu_player.playing,"mute/settings/reconnect cannot restart music")
 client._received({"type":"duel_state","code":"123456","match_finished":true})
 ck(not policy.menu_player.playing,"results remain silent")
 client.queue_free();await create_timer(.1).timeout
 ck(policy.menu_player.playing,"real menu resumes on full exit")
 var sample=Node.new();root.add_child(sample);policy.sample_playback(sample,true)
 ck(not policy.menu_player.playing,"Guess Sound pauses menu")
 var before: int=policy._active_effects;policy.effect("correct")
 ck(policy._active_effects==before,"effects suppressed while sound clip active")
 policy.sample_playback(sample,false);ck(policy.menu_player.playing,"sample completion restores eligible menu")
 for name in ["startup","click","navigation","selection","room_create","player_join","all_ready","countdown","round_start","correct","incorrect","victory","results"]:
  ck(policy._asset(name).get_length()>.05,"decodable effect "+name)
 for pair in [["selection","UI SFX"],["correct","Game SFX"]]:
  var capture=AudioEffectCapture.new();var fx_bus=AudioServer.get_bus_index(pair[1]);AudioServer.add_bus_effect(fx_bus,capture)
  policy.effect(pair[0],pair[1]=="UI SFX");await create_timer(.2).timeout
  var frames=capture.get_buffer(capture.get_frames_available());var fx_peak: float=0
  for frame in frames:fx_peak=maxf(fx_peak,maxf(absf(frame.x),absf(frame.y)))
  ck(fx_peak>.0001,"effect PCM on "+pair[1])
 policy.room_snapshot(sample,{"joined":1,"capacity":2,"confirmed":[false,false]})
 policy.room_snapshot(sample,{"joined":2,"capacity":2,"confirmed":[true,true]})
 ck(policy._last_effect.has("all_ready"),"all ready event dispatched under effect load")
 policy.room_snapshot(sample,{"joined":2,"capacity":2,"confirmed":[true,true],"started":true})
 ck(policy._last_effect.has("round_start"),"round start event dispatched")
 policy.set_music_enabled(false);ck(not policy.menu_player.playing,"saved off remains silent")
 sample.queue_free();quit(1 if failed else 0)
