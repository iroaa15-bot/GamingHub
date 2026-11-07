extends SceneTree
var folder: String="user://player_card_captures"
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 root.content_scale_size=Vector2i(420,900)
 root.get_node("PublishedContent").busy=true
 root.get_node("RoomAudioPolicy").set_music_enabled(false)
 root.get_node("RoomAudioPolicy").set_effects_enabled(false)
 var ui=load("res://scripts/photo_duel_extension_ui.gd").new()
 root.add_child(ui)
 ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 ui.client.player=0;ui.client.code="QAONLY"
 ui.client.capabilities={"room_agreement":true,"primary_modes":["tap"]}
 var valid: bool=true
 for language in ["ar","en"]:
  ui.language=language
  ui.layout_direction=Control.LAYOUT_DIRECTION_RTL if language=="ar" else Control.LAYOUT_DIRECTION_LTR
  for count in range(2,7):
   var profiles: Array=[]
   var connected: Array=[]
   var scores: Array=[]
   for i in range(count):
    profiles.append({"display_name":("لاعب باسم طويل واضح " if language=="ar" else "Long readable player name ")+str(i+1)})
    connected.append(i!=count-1);scores.append(count-i)
   var state: Dictionary={"capacity":count,"joined":count,"connected":connected,"scores":scores,"profiles":profiles,"started":true,"current":0,"responder":1,"primary_mode":"tap","room_agreement":true,"opponents":[]}
   ui.client.state=state;ui._state(state)
   await process_frame;await process_frame
   valid=valid and ui._seat_avatars[0].custom_minimum_size.x>=(80 if count==2 else 56)
   valid=valid and ui._seat_labels[0].text.contains("♛") and ui._seat_labels[0].text.contains("★")
   valid=valid and ui._seat_labels[count-1].text.contains("إعادة اتصال" if language=="ar" else "Reconnecting")
   if DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder.path_join("cards-%s-%d.png"%[language,count]))
 print("PLAYER_CARDS_LAYOUT ",valid," 2..6 AR/EN rendering fixtures; not device multiplayer")
 ui.queue_free();await process_frame
 quit(0 if valid else 1)
