extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 create_timer(15).timeout.connect(func():quit(2))
 var policy=root.get_node("RoomAudioPolicy")
 await create_timer(.1).timeout
 assert(policy._asset("ui_click").get_length()<.035)
 var player=policy.menu_player
 player.seek(3.0)
 policy.set_music_volume(.35);policy.set_effects_volume(.4)
 var room:=Node.new();root.add_child(room);policy.membership(room,true)
 assert(policy.menu_player==player and player.playing and player.get_playback_position()>2.9)
 assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),linear_to_db(.35)-18))
 policy._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 assert(player.stream_paused)
 policy._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
 assert(not player.stream_paused and player.get_playback_position()>2.9)
 policy.effect("click",true);policy._last_effect.clear();policy.effect("navigation",true)
 var ui_count:=0
 for effect in policy._effect_players:
  if effect.bus=="UI SFX":
   ui_count+=1
   assert(effect.stream==policy._asset("ui_click"))
 assert(ui_count==1)
 policy.membership(room,false)
 assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),linear_to_db(.35)))
 var main=load("res://scripts/main.gd").new();root.add_child(main)
 main._apply_audio_preferences({"music_enabled":false,"sound_enabled":true,"music_volume":.25,"effects_volume":.5})
 assert(is_equal_approx(policy.music_volume,.25) and is_equal_approx(policy.effects_volume,.5) and player.stream_paused)
 main.queue_free();room.queue_free();await process_frame
 print("CHALLENGE_AUDIO_PASS — loop state, volume restore, room ducking, background pause and single non-tonal UI click")
 quit(0)
