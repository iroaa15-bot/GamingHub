extends SceneTree
class RecordingClient:
 extends "res://scripts/photo_duel_extension_client.gd"
 var sent: Array=[]
 func _ready() -> void:pass
 func send_action(kind: String, fields: Dictionary={}) -> Error:
  sent.append({"type":kind,"fields":fields.duplicate(true)})
  return OK
var failed := false
var captures := ""
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
 if not value:failed=true;push_error("PARTY_PLAY_VIEW: "+message)
func snap(name_value: String) -> void:
 await process_frame;await process_frame
 if captures.is_empty() or DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(captures.path_join(name_value+".png"))
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):captures=arg.trim_prefix("--capture-dir=")
 if not captures.is_empty():DirAccess.make_dir_recursive_absolute(captures)
 root.content_scale_size=Vector2i(420,840)
 root.size=Vector2i(420,840)
 root.get_node("PublishedContent").busy=true
 root.get_node("GamingHubAccount").api_base=""
 var audio=root.get_node("RoomAudioPolicy");audio.set_music_enabled(false);audio.set_effects_enabled(false)
 root.set_meta("reduced_motion",true)
 var script=load("res://scripts/social_room_ui.gd");script.selected_social="open_heart"
 for language in ["ar","en"]:
  var ui=script.new();ui.language=language;root.add_child(ui)
  ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  await process_frame
  var transport=ui.client
  ui.client=RecordingClient.new();root.add_child(ui.client)
  ui.client.code="123456";ui.client.player=0
  ui.client.capabilities={"voice":true,"room_agreement":true,"primary_modes":["voice","text","mixed","tap"]}
  for count in range(2,7):
   var state: Dictionary={"capacity":count,"joined":count,"connected":[],"confirmed":[],"scores":[],"profiles":[],"current":0,"host":0,"started":false,"room_agreement":true,"config_revision":1,"picture_difficulty":"easy","primary_mode":"voice","party":{"category":"open_heart","phase":"lobby","round":0,"rounds":10}}
   for i in range(count):
    state.connected.append(true);state.confirmed.append(i==0);state.scores.append(0)
    state.profiles.append({"display_name":(["عمر","نورا","أحمد","سارة","حور","زين"] if language=="ar" else ["Omar","Nora","Ahmed","Sara","Hoor","Zain"])[i]})
   ui.client.state=state;ui._state(state);await process_frame
   check(ui.play_view.visible and ui._seats.is_visible_in_tree(),"lobby and seats visible")
   if count==2:await snap("lobby-"+language)
   state.started=true;state.party.phase="active";state.party.actor="0";state.party.card_id="fixture"
   state.party.card={"text_ar":"إيه أجمل حاجة حصلت لك الأسبوع ده؟","text_en":"What was the best part of your week?"}
   ui.client.state=state;ui._state(state);await process_frame;await process_frame
   var card_id: int=ui.play_view.card.get_instance_id()
   var mute_position: Vector2=ui.voice_mute_button.global_position
   check(ui.play_view.participate.is_visible_in_tree() and not ui.play_view.participate.disabled,"actor can participate")
   check(ui.voice_mute_button.get_global_rect().end.y<=root.size.y,"mute stays on screen")
   check(ui.play_view.card.get_global_rect().end.y<=ui.play_view.scroll.get_global_rect().end.y,"full prompt fits with 2..6 compact seats")
   ui._state(state);await process_frame;await process_frame
   check(card_id==ui.play_view.card.get_instance_id(),"snapshot retains prompt node")
   check(mute_position.is_equal_approx(ui.voice_mute_button.global_position),"snapshot retains mute position")
   if count in [2,6]:await snap("active-%s-%d"%[language,count])
   var before: int=ui.client.sent.size()
   ui.play_view.submit("finish",true);ui.play_view.submit("finish",false)
   check(ui.client.sent.size()==before+1,"repeat tap submits only once")
   ui._state(state)
   check(ui.play_view.participate.disabled,"same snapshot does not unlock pending submission")
   state.paused=true;ui.client.state=state;ui._state(state);await process_frame;await process_frame
   check(ui.play_view.participate.disabled and ui.play_view.skip.disabled,"pause blocks answers")
   check(ui.client.sent.size()==before+1,"pause does not replay answer")
   check(mute_position.is_equal_approx(ui.voice_mute_button.global_position),"pause retains mute position")
   if count==2:await snap("reconnecting-"+language)
   ui.play_view.rejected({"type":"duel_resumed"})
   check(not ui.play_view.pending_key.is_empty(),"resume acknowledgement waits for canonical snapshot")
   state.paused=false;ui.client.state=state;ui._state(state)
   check(ui.play_view.pending_key.is_empty() and not ui.play_view.participate.disabled,"authoritative resumed active state permits explicit retry")
   check(ui.client.sent.size()==before+1,"resume never replays answer")
   state.paused=false;state.party.phase="results";state.party.round=1;state.scores[0]=10
   state.party.result={"awards":{"0":10}}
   ui.client.state=state;ui._state(state);await process_frame;await process_frame
   check(ui.play_view.next_round.is_visible_in_tree(),"host next-round action")
   check(mute_position.is_equal_approx(ui.voice_mute_button.global_position),"results retain mute position")
   if count==2:await snap("results-"+language)
   state.party.phase="finished";state.party.round=10;state.match_finished=true;state.winner=-1;state.voice={"available":true}
   ui.client.state=state;ui._state(state);await process_frame;await process_frame
   check(ui.play_view.instruction.text.contains("draw") or ui.play_view.instruction.text.contains("بالتعادل"),"draw is explicit")
   check(ui.play_view.detail.text.contains("voice") or ui.play_view.detail.text.contains("المكالمة"),"available voice is reflected in final results")
   state.paused=true;ui.client.state=state;ui._state(state);await process_frame
   check(not ui.play_view.detail.text.contains("voice") and not ui.play_view.detail.text.contains("المكالمة"),"paused room does not claim voice availability")
   state.paused=false
   state.primary_mode="tap";ui.client.state=state;ui._state(state);await process_frame
   check(not ui.play_view.detail.text.contains("voice") and not ui.play_view.detail.text.contains("المكالمة"),"tap mode does not claim voice availability")
   state.primary_mode="voice";ui.client.state=state;ui._state(state);await process_frame
   check(mute_position.is_equal_approx(ui.voice_mute_button.global_position),"finished retains mute position")
   if count==2:await snap("finished-"+language)
   state.closed=true;ui.client.state=state;ui._state(state)
   check(not ui.play_view.visible and not ui.play_view.card.is_visible_in_tree(),"closed room hides stale prompt")
  ui.client.queue_free();ui.client=transport
  ui.queue_free();await process_frame
 print("PARTY_PLAY_VIEW_PASS="+str(not failed)+" AR/EN 2..6 lobby/active/pause/results/finished/closed stable mute and prompt")
 quit(1 if failed else 0)
