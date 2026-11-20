extends RefCounted
const PlaySkin=preload("res://scripts/visual_skin.gd")
static func selector(main: Control, title: String, values: Array, captions: Array, selected: Variant, changed: Callable) -> void:
 main.label(title,17)
 var field:=OptionButton.new();field.size_flags_horizontal=Control.SIZE_EXPAND_FILL;field.custom_minimum_size.y=56
 for i in range(values.size()):
  field.add_item(str(captions[i]))
  if values[i]==selected:field.selected=i
 field.item_selected.connect(func(index: int):changed.call(values[index]))
 if selected not in values:changed.call(values[0])
 main.root.add_child(field);PlaySkin.decorate_selector(field)
static func render(main: Control) -> void:
 main.clear_ui();main.current_screen="offline_setup"
 var art:=TextureRect.new();art.texture=PlaySkin.game_cover(main.game);art.custom_minimum_size.y=100
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;main.root.add_child(art)
 main.label(main.game_title(main.game),28);main.label(main.tr_ui("جهّز جولتك","MAKE IT YOUR ROUND"),18)
 selector(main,main.tr_ui("المستوى","Difficulty"),[1,2,3],[main.difficulty_name(1),main.difficulty_name(2),main.difficulty_name(3)],main.difficulty,func(value):main.difficulty=value)
 if main.game==8:
  main.session_length=4*clampi(ceili(float(main.session_length)/4.0),3,5)
  selector(main,main.tr_ui("عدد لوحات الذاكرة","Memory boards"),[12,16,20],["3","4","5"],main.session_length,func(value):main.session_length=value)
 elif main.game==0:
  selector(main,main.tr_ui("عدد الصور","Pictures"),[10,15,20],["5","8","10"],main.session_length,func(value):main.session_length=value)
 elif main.game!=4:
  selector(main,main.tr_ui("عدد الأسئلة","Questions"),[5,10,15,20],["5","10","15","20"],main.session_length,func(value):main.session_length=value)
 if main.game in [0,8]:
  var decks: Array=["all","Animal","Food","Object","Place"];var captions: Array=[]
  for key in decks:captions.append(main.deck_title(key))
  selector(main,main.tr_ui("مجموعة الصور","Picture collection"),decks,captions,main.deck,func(value):main.deck=value)
 elif main.game!=4:
  var topics: Array=["all"];var captions: Array=[main.topic_title("all")]
  for item in main.eligible_questions(main.game,false):
   var topic: String=str(item.get("topic",""))
   if not topic.is_empty() and topic not in topics:topics.append(topic);captions.append(main.topic_title(topic))
  selector(main,main.tr_ui("الفئة","Category"),topics,captions,main.selected_topic,func(value):main.selected_topic=value)
  selector(main,main.tr_ui("طريقة الجولة","Round style"),["classic","survival","rival","blitz"],[main.tr_ui("كلاسيكي · بدون مؤقت","Classic · untimed"),main.tr_ui("البقاء · 3 محاولات","Survival · 3 lives"),main.tr_ui("سباق نقاط · منافس محلي","Score race · local rival"),main.tr_ui("سرعة · مؤقت حسب المستوى","Blitz · timed by difficulty")],main.match_style,func(value):main.match_style=value)
 else:
  selector(main,main.tr_ui("المغامرة","Adventure"),["island","archive"],[main.tr_ui("جزيرة المنارة","Lighthouse island"),main.tr_ui("أرشيف الأسرار","Secret archive")],main.selected_campaign,func(value):main.selected_campaign=value)
 main.label(main.tr_ui("الجولة حسب المحتوى المتاح في مجموعتك.","Rounds use available content in your collection."),14)
 main.button(main.tr_ui("ابدأ اللعب","LET’S PLAY"),func():main.quick_match_active=false;main.start_game(),main.GREEN).set_meta("setup_action","start")
 main.button(main.tr_ui("خيارات لعب إضافية","More play options"),func():main._show_legacy_game_options(main.game),main.PANEL)
 main.button(main.tr_ui("اختيار النمط","Choose mode"),func():main.show_modes(main.game),main.PANEL)
