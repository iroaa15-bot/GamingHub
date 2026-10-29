extends Node
## Scene-independent music exclusion. Native voice routing remains owned by its plugin.
const BUS_NAMES=["Music","UI SFX","Game SFX","Voice Chat"]
var music_enabled:=true
var _members: Dictionary={}
var _music: Array[WeakRef]=[]
var _fade: Tween
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
func register_music(player: AudioStreamPlayer) -> void:
 player.bus="Music";_music.append(weakref(player))
 if not music_enabled or not _members.is_empty():player.stop()
func set_music_enabled(enabled: bool) -> void:
 music_enabled=enabled
 if not enabled:_silence()
 elif _members.is_empty():_resume()
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
  if _members.is_empty() and music_enabled:_resume()
func _music_db(db: float) -> void:
 AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),db)
func _silence() -> void:
 AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),true)
 for ref in _music:
  var player=ref.get_ref()
  if is_instance_valid(player):player.stop()
func _resume() -> void:
 if is_instance_valid(_fade):_fade.kill()
 _music_db(0);AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),false)
 for ref in _music:
  var player=ref.get_ref()
  if is_instance_valid(player) and not player.playing:player.play()
func music_blocked() -> bool:return not _members.is_empty()
