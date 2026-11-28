extends SceneTree
var failed:=false
func _initialize() -> void:call_deferred("run")
func ck(value: bool,message: String) -> void:
 if not value:failed=true;push_error(message)
func run() -> void:
 root.get_node("PublishedContent").busy=true;root.get_node("GamingHubAccount").api_base=""
 root.get_node("RoomAudioPolicy").set_music_enabled(false);root.get_node("RoomAudioPolicy").set_effects_enabled(false)
 for category in ["open_heart","act_it","who_among_us","show_skill","truth_or_fiction","table_flip"]:
  var ui=load("res://scripts/"+category+"_offline.gd").new();root.add_child(ui)
  await process_frame;await process_frame
  ck(ui.names_input.has_meta("player_setup_bound") and not ui.names_input.visible,category+" uses player fields")
  var setup=ui.names_input.get_parent().get_children().filter(func(n):return n.get_script()!=null and n.get_script().resource_path=="res://scripts/local_player_setup.gd")[0]
  setup.fields[0].text="عمر";setup.fields[1].text="نورا";setup.count=2;setup.refresh_rows();setup.write_names()
  ck(ui.names_input.text=="عمر, نورا",category+" adapts names without changing setup rules")
  ck(setup.remove_button.disabled,category+" keeps at least two players")
  ui._start();await process_frame;await process_frame
  var players: Array=ui.players if category=="table_flip" else ui.engine.players
  ck(players.size()==2 and players[0]=="عمر",category+" starts with actual player names")
  ui.queue_free();await process_frame
 print("LOCAL_PARTY_SETUP_PASS="+str(not failed)+" all six games, names, two-player minimum and existing engine setup")
 quit(1 if failed else 0)
