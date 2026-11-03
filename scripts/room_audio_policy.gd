extends Node
## Scene-independent music exclusion. Native voice routing remains owned by its plugin.
const BUS_NAMES=["Music","UI SFX","Game SFX","Voice Chat"]
var music_enabled:=true
var _members: Dictionary={}
var _music: Array[WeakRef]=[]
var _fade: Tween
var ui_effects_enabled:=true
var game_effects_enabled:=true
# Compatibility for existing callers that intentionally toggle both effect buses.
var effects_enabled: bool:
 get:return ui_effects_enabled or game_effects_enabled
 set(value):set_effects_enabled(value)
var menu_player: AudioStreamPlayer
var _samples: Dictionary={}
var _last_effect: Dictionary={}
var _active_effects:=0
var _effect_players: Array[AudioStreamPlayer]=[]
var _room_marks: Dictionary={}
var _stream_cache: Dictionary={}
func _asset(name: String) -> AudioStream:
 if not _stream_cache.has(name):_stream_cache[name]=load("res://assets/audio/premium/"+name+".wav")
 return _stream_cache[name]
func _start_menu() -> void:
 if music_enabled and not music_blocked():_resume()
 effect("startup")
func set_effects_enabled(enabled: bool) -> void:
 set_ui_effects_enabled(enabled)
 set_game_effects_enabled(enabled)
func set_ui_effects_enabled(enabled: bool) -> void:
 ui_effects_enabled=enabled
 var index=AudioServer.get_bus_index("UI SFX")
 if index>=0:AudioServer.set_bus_mute(index,not enabled)
 if not enabled:_stop_effects("UI SFX")
func set_game_effects_enabled(enabled: bool) -> void:
 game_effects_enabled=enabled
 var index=AudioServer.get_bus_index("Game SFX")
 if index>=0:AudioServer.set_bus_mute(index,not enabled)
 if not enabled:_stop_effects("Game SFX")
func _stop_effects(bus: String="") -> void:
 for player in _effect_players.duplicate():
  if not bus.is_empty() and player.bus!=bus:continue
  player.stop();player.queue_free();_effect_players.erase(player)
 _active_effects=_effect_players.size()
func effect(name: String,ui: bool=false) -> void:
 if (not ui_effects_enabled if ui else not game_effects_enabled) or not _samples.is_empty():return
 if name in ["all_ready","round_start","correct","incorrect","victory","results"] and _active_effects>=2:
  var old: AudioStreamPlayer=_effect_players.pop_front();old.stop();old.queue_free();_active_effects-=1
 if _active_effects>=3:return
 var now=Time.get_ticks_msec()
 if now-int(_last_effect.get(name,-10000))<(90 if ui else 350):return
 if name not in ["startup","click","navigation","selection","room_create","player_join","all_ready","countdown","round_start","correct","incorrect","victory","results"]:return
 _last_effect[name]=now
 var player=AudioStreamPlayer.new();player.stream=_asset(name)
 player.bus="UI SFX" if ui else "Game SFX";player.volume_db=-14 if ui else -12
 add_child(player);_active_effects+=1;_effect_players.append(player)
 player.finished.connect(func():
  if _effect_players.has(player):_effect_players.erase(player);_active_effects-=1
  player.queue_free())
 player.play()
 if OS.is_debug_build():print("GH_AUDIO_EFFECT ",name," bus=",player.bus)
func sample_playback(owner: Object,active: bool) -> void:
 var id=owner.get_instance_id()
 if active:
  if _samples.has(id):return
  _samples[id]=true
  _stop_effects()
  if is_instance_valid(_fade):_fade.kill()
  _silence()
 else:
  if not _samples.has(id):return
  _samples.erase(id)
  if not music_blocked() and music_enabled:_resume()
func room_snapshot(owner: Object,value: Dictionary) -> void:
 var id=owner.get_instance_id();var prior: Dictionary=_room_marks.get(id,{})
 var joined: int=int(value.get("joined",0));var capacity: int=int(value.get("capacity",2))
 var all_ready: bool=joined==capacity and value.get("confirmed",[]).count(true)==capacity
 if joined>int(prior.get("joined",joined)) and joined>1:effect("player_join")
 if all_ready and not bool(prior.get("ready",false)):effect("all_ready")
 if bool(value.get("started",false)) and not bool(prior.get("started",false)):effect("round_start")
 if bool(value.get("match_finished",false)) and not bool(prior.get("finished",false)):effect("victory")
 var history: Array=value.get("history",[])
 if not prior.is_empty() and history.size()>int(prior.get("history_size",history.size())) and not history.is_empty():
  var entry: Dictionary=history.back()
  if entry.get("kind")=="confirmation":effect("correct" if bool(entry.get("answer",false)) else "incorrect")
 _room_marks[id]={"joined":joined,"ready":all_ready,"started":value.get("started",false),"finished":value.get("match_finished",false),"history_size":value.get("history",[]).size()}
static func acquire(tree: SceneTree) -> Node:
 var found=tree.root.get_node_or_null("RoomAudioPolicy")
 if found!=null:return found
 var policy=load("res://scripts/room_audio_policy.gd").new()
 policy.name="RoomAudioPolicy";tree.root.add_child(policy)
 return policy
func _ready() -> void:
 for bus in BUS_NAMES:
  if AudioServer.get_bus_index(bus)<0:
   AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
   AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
 AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI SFX"),-6)
 set_ui_effects_enabled(ui_effects_enabled);set_game_effects_enabled(game_effects_enabled)
 menu_player=AudioStreamPlayer.new();menu_player.name="MenuMusic"
 var stream: AudioStreamWAV=_asset("menu_sunrise")
 stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=int(round(stream.get_length()*stream.mix_rate))
 menu_player.stream=stream;menu_player.volume_db=-8
 add_child(menu_player);register_music(menu_player)
 call_deferred("_start_menu")
func register_music(player: AudioStreamPlayer) -> void:
 player.bus="Music";_music.append(weakref(player))
 if not music_enabled or music_blocked():player.stop()
func set_music_enabled(enabled: bool) -> void:
 music_enabled=enabled
 if not enabled:_silence()
 elif not music_blocked():_resume()
func membership(owner: Object,joined: bool) -> void:
 var key=owner.get_instance_id()
 if joined:
  if _members.has(key):return
  _members[key]=true
  if _members.size()==1:
   if is_instance_valid(_fade):_fade.kill()
   _fade=create_tween();_fade.tween_method(_music_db,0.0,-60.0,.15)
   _fade.tween_callback(_silence)
 else:
  _members.erase(key)
  _room_marks.erase(key)
  if not music_blocked() and music_enabled:_resume()
func _music_db(db: float) -> void:
 AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),db)
func _silence() -> void:
 var changed: bool=not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
 AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),true)
 for ref in _music:
  var player=ref.get_ref()
  if is_instance_valid(player):player.stop()
 if changed and OS.is_debug_build():print("GH_AUDIO_MUSIC STOP muted=true membership=",not _members.is_empty())
func _resume() -> void:
 if is_instance_valid(_fade):_fade.kill()
 _music_db(0);AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),false)
 for ref in _music:
  var player=ref.get_ref()
  if is_instance_valid(player) and not player.playing:
   player.play()
   if OS.is_debug_build():print("GH_AUDIO_MUSIC PLAY membership=",not _members.is_empty()," enabled=",music_enabled)
func music_blocked() -> bool:return not _members.is_empty() or not _samples.is_empty()

func _exit_tree() -> void:
 if is_instance_valid(_fade):_fade.kill()
 if is_instance_valid(menu_player):menu_player.stop()
 for player in _effect_players:
  if is_instance_valid(player):player.stop()
 _effect_players.clear();_music.clear();_stream_cache.clear()
