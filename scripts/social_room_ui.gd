extends "res://scripts/photo_duel_extension_ui.gd"
## Reuses verified room membership, player cards, reconnect and voice components.
static var selected_social := "open_heart"
var party_panel: VBoxContainer
const SOCIAL_TITLES := {"open_heart":["افتح قلبك","Open Heart"],"act_it":["مثّل وورّينا","Act It"],"who_among_us":["مين فينا؟","Who Among Us"],"show_skill":["ورّينا شطارتك","Show Your Skill"],"truth_or_fiction":["صدق ولا تأليف؟","Truth or Fiction"],"table_flip":["اقلب الترابيزة","Flip the Table"]}

static func rooms_available() -> bool:
 var endpoint: String=Client.endpoint_from_args()
 return Client.allowed_endpoint(endpoint)

func _ready() -> void:
 super._ready()
 # Start with the common handshake so an older service can report availability
 # without receiving an unsupported game identifier.
 client.requested_game=""
 target_field.min_value=10;target_field.max_value=20;target_field.step=5;target_field.value=10
 for child in _settings_body.get_children():
  if child is Label and child.text in ["نقاط الفوز","Winning score"]:child.text=tr_pair("عدد الجولات","Number of rounds")
 for child in _main_column.get_node("CompactHeader").get_children():
  if child is Label:child.text=str(SOCIAL_TITLES[selected_social][0 if language=="ar" else 1])
 for i in range(4):_mode_field.set_item_text(i,(["صوت","كتابة","صوت وكتابة","نقر"] if language=="ar" else ["Voice","Text","Voice and text","Tap"])[i])
 party_panel=VBoxContainer.new();party_panel.add_theme_constant_override("separation",12);_main_column.add_child(party_panel)
 _state(client.state)

func _create_filtered_room() -> void:
 client.send_action("duel_party_create",{"category":selected_social,"players":players_field.get_selected_id(),"rounds":int(target_field.value)})

func _room_protocol_ready(capabilities: Dictionary) -> void:
 if selected_social not in capabilities.get("party_games",[]):
  _pending_room_action=""
  status.text=tr_pair("غرف هذه اللعبة غير متاحة حاليًا. يمكنك اللعب بدون إنترنت.","Rooms for this game are currently unavailable. Offline play is available.")
  return
 if client.requested_game!="party:"+selected_social:
  client.requested_game="party:"+selected_social
  client.send_action("duel_hello",{"game_id":client.requested_game})
  return
 super._room_protocol_ready(capabilities)

func _propose_configuration() -> void:
 client.send_action("duel_party_propose",{"primary_mode":["voice","text","mixed","tap"][_mode_field.selected]})

func _party_action(kind: String, fields: Dictionary={}) -> void:
 var payload: Dictionary=fields.duplicate(true)
 if not payload.has("card_id"):payload["card_id"]=str(client.state.get("party",{}).get("card_id",""))
 client.send_action(kind,payload)

func _social_player_name(index: int) -> String:
 var profiles: Array=client.state.get("profiles",[])
 if index>=0 and index<profiles.size() and profiles[index] is Dictionary:
  var verified_name: String=str(profiles[index].get("display_name","")).strip_edges()
  if not verified_name.is_empty():return verified_name
 return tr_pair("اللاعب %d","Player %d") % [index+1]

func _state(value: Dictionary) -> void:
 super._state(value)
 _match_controls.hide();_online_filter_box.hide();_online_category.hide();timer_field.hide();pass_button.hide();_voice_question.hide()
 if not is_instance_valid(party_panel):return
 for child in party_panel.get_children():party_panel.remove_child(child);child.queue_free()
 var party: Dictionary=value.get("party",{})
 var phase: String=str(party.get("phase","lobby"))
 party_panel.visible=phase!="lobby" and not party.is_empty() and not bool(value.get("closed",false)) and not client.code.is_empty()
 if not party_panel.visible:return
 _main_column.move_child(party_panel,_main_column.get_children().find(_match_controls))
 var saved_column=column;column=party_panel
 var round_number: int=int(party.get("round",0))
 heading.text=tr_pair("الجولة %d من %d","Round %d of %d") % [mini(round_number+1,int(party.get("rounds",10))),int(party.get("rounds",10))]
 var paused: bool=bool(value.get("paused",false))
 var actor: String=str(party.get("actor",""))
 var is_actor: bool=actor==str(client.player)
 var category: String=str(party.get("category",selected_social))
 if phase in ["results","finished"]:
  label(tr_pair("انتهت المباراة" if phase=="finished" else "نتيجة الجولة","Match finished" if phase=="finished" else "Round results"),26)
  var results: Array=value.get("scores",[])
  for i in range(results.size()):label(tr_pair("%s: %d نقطة","%s: %d points") % [_social_player_name(i),int(results[i])],23)
  if phase=="results" and client.player==0:button(tr_pair("الجولة التالية","Next round"),func():client.send_action("duel_party_next",{"round":round_number}))
 else:
  label(tr_pair("دورك الآن","Your turn") if is_actor else tr_pair("الدور على: %s","Turn: %s") % [_social_player_name(int(actor))],24)
  var card: Dictionary=party.get("card",{}) if party.get("card") is Dictionary else {}
  if not card.is_empty():
   label(str(card.get("text_en",card.get("text_ar",""))) if language=="en" else str(card.get("text_ar","")),26)
   if language=="en" and not card.has("text_en"):label("These cards are in Arabic.",16)
  elif category in ["act_it","show_skill"]:label(tr_pair("شاهد أداء اللاعب ثم صوّت.","Watch the player's performance, then vote."))
  var voted: bool=str(client.player) in party.get("voted_players",[])
  if category=="open_heart" and is_actor:
   button(tr_pair("شاركت • +10 نقاط","Participated • +10 points"),func():_party_action("duel_party_finish",{"participated":true}))
   button(tr_pair("تخطي بدون نقاط","Skip without points"),func():_party_action("duel_party_finish",{"participated":false}))
  elif category=="who_among_us" and not voted:
   for i in range(int(value.get("capacity",2))):
    if i==client.player:continue
    var nominee: String=str(i)
    button(tr_pair("اختر: %s","Choose: %s") % [_social_player_name(i)],func():_party_action("duel_party_vote",{"choice":nominee}))
  elif category=="truth_or_fiction" and not bool(party.get("story_committed",false)):
   if is_actor:
    button(tr_pair("قصتي حقيقية • اختيار سري","My story is true • secret"),func():_party_action("duel_party_story",{"is_true":true}))
    button(tr_pair("قصتي تأليف • اختيار سري","My story is fiction • secret"),func():_party_action("duel_party_story",{"is_true":false}))
   else:label(tr_pair("انتظر اختيار صاحب القصة السري.","Wait for the storyteller's secret choice."))
  elif category in ["act_it","show_skill","truth_or_fiction"] and not is_actor and not voted:
   button(tr_pair("حقيقية" if category=="truth_or_fiction" else "نعم","True" if category=="truth_or_fiction" else "Yes"),func():_party_action("duel_party_vote",{"choice":true}))
   button(tr_pair("تأليف" if category=="truth_or_fiction" else "لا","Fiction" if category=="truth_or_fiction" else "No"),func():_party_action("duel_party_vote",{"choice":false}))
  elif category=="table_flip" and is_actor:
   if bool(party.get("choosing",false)):
    for offer in party.get("offered",[]):
     var selected_id: String=str(offer.id)
     button(str(offer.get("text_ar","")),func():_party_action("duel_party_choose",{"card_id":selected_id}))
   elif str(party.get("power","")) in ["bonus","steal","skip"]:
    for i in range(int(value.get("capacity",2))):
     if i==client.player:continue
     var target: String=str(i)
     button(tr_pair("نفّذ على: %s","Apply to: %s") % [_social_player_name(i)],func():_party_action("duel_party_power",{"target":target}))
   else:button(tr_pair("نفّذ قوة الكارت","Apply card power"),func():_party_action("duel_party_power"))
  elif voted:label(tr_pair("تم التصويت؛ انتظر باقي اللاعبين.","Vote recorded; waiting for the other players."))
 for control in party_panel.find_children("*","Button",true,false):
  control.disabled=paused
  control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  control.custom_minimum_size.y=maxf(control.custom_minimum_size.y,60)
 column=saved_column
 VisualSkin.compact_menu(party_panel)
