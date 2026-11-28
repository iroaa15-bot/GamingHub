extends RefCounted
const PlaySkin=preload("res://scripts/visual_skin.gd")
static func picture_difficulty(main: Control) -> void:
 var surface:=PanelContainer.new()
 var style:=PlaySkin.play_surface(Color("081b43"),14)
 style.border_color=Color("3569bc")
 surface.add_theme_stylebox_override("panel",style);main.root.add_child(surface)
 var content:=VBoxContainer.new();content.add_theme_constant_override("separation",6);surface.add_child(content)
 var heading:=Label.new();heading.text=main.tr_ui("مستوى الصعوبة","Difficulty")
 heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 heading.add_theme_font_size_override("font_size",int(16*main.reading_scale));content.add_child(heading)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);content.add_child(row)
 var group:=ButtonGroup.new()
 var titles: Array=[main.tr_ui("سهل","Easy"),main.tr_ui("متوسط","Medium"),main.tr_ui("صعب","Hard")]
 for i in range(3):
  var value: int=i+1
  var caption: String=titles[i]
  var choice:=Button.new();choice.text=caption;choice.toggle_mode=true;choice.button_group=group
  choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choice.custom_minimum_size.y=48
  choice.add_theme_font_size_override("font_size",int(15*main.reading_scale))
  PlaySkin.decorate_play_action(choice,["positive","reward","danger"][i])
  choice.toggled.connect(func(on: bool):choice.text=("✓ " if on else "")+caption)
  choice.button_pressed=main.difficulty==value
  choice.set_meta("difficulty_value",value)
  choice.pressed.connect(func():main.difficulty=value)
  row.add_child(choice)
static func selector(main: Control, title: String, values: Array, captions: Array, selected: Variant, changed: Callable) -> void:
 var surface := PanelContainer.new()
 var style := PlaySkin.play_surface(Color("081b43"), 14)
 style.border_color = Color("3569bc")
 style.content_margin_left = 10; style.content_margin_right = 10
 style.content_margin_top = 6; style.content_margin_bottom = 6
 surface.add_theme_stylebox_override("panel", style)
 main.root.add_child(surface)
 var long_choice := false
 for caption in captions:
  if str(caption).length() > 22: long_choice = true
 var row: BoxContainer = VBoxContainer.new() if main.reading_scale >= 1.25 or long_choice else HBoxContainer.new()
 row.add_theme_constant_override("separation", 8)
 surface.add_child(row)
 var heading := Label.new()
 heading.text = title
 heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 heading.add_theme_font_size_override("font_size", int(16 * main.reading_scale))
 heading.add_theme_color_override("font_color", Color("e4efff"))
 row.add_child(heading)
 var field := OptionButton.new()
 field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 field.custom_minimum_size.y = 52
 field.add_theme_font_size_override("font_size", int(16 * main.reading_scale))
 field.clip_text = true
 for i in range(values.size()):
  field.add_item(str(captions[i]))
  if values[i] == selected: field.selected = i
 field.item_selected.connect(func(index: int): changed.call(values[index]))
 if selected not in values: changed.call(values[0])
 row.add_child(field)
 PlaySkin.decorate_selector(field)

static func cinema_topics(main: Control, topics: Array, captions: Array) -> void:
 # Build cards only for topics that have approved content. The reference is
 # illustrative; it does not create new categories or questions.
 if main.selected_topic not in topics:main.selected_topic="all"
 var heading:=Label.new()
 heading.text=main.tr_ui("اختر الفئة","Choose category")
 heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 heading.add_theme_font_size_override("font_size",int(18*main.reading_scale))
 main.root.add_child(heading)
 var grid:=GridContainer.new();grid.columns=2
 grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8)
 main.root.add_child(grid)
 var group:=ButtonGroup.new()
 for i in range(topics.size()):
  var key: String=str(topics[i])
  var tile:=Button.new();tile.text=str(captions[i]);tile.toggle_mode=true;tile.button_group=group
  tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.custom_minimum_size.y=76 if main.reading_scale<1.25 else 100
  tile.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  var tile_font_size: int=int(16*main.reading_scale)
  tile.icon=PlaySkin.game_cover(1) if key=="cinema" else PlaySkin.menu_icon("settings" if key=="craft" else "list")
  tile.expand_icon=true;tile.add_theme_constant_override("icon_max_width",36)
  tile.set_meta("topic_value",key)
  tile.toggled.connect(func(on: bool):
   PlaySkin.decorate_button(tile,"blue" if on else "violet")
   tile.add_theme_font_size_override("font_size",tile_font_size)
  )
  tile.pressed.connect(func():main.selected_topic=key)
  grid.add_child(tile)
  tile.button_pressed=main.selected_topic==key
  PlaySkin.decorate_button(tile,"blue" if tile.button_pressed else "violet")
  tile.add_theme_font_size_override("font_size",tile_font_size)

static func render(main: Control) -> void:
 main.clear_ui();main.current_screen="offline_setup"
 main.root.add_theme_constant_override("separation", 8)
 var header := PanelContainer.new()
 var header_style := PlaySkin.play_surface(Color("0a1b45"), 18)
 header_style.border_color = Color("46b9ff")
 header_style.set_border_width_all(2)
 header.add_theme_stylebox_override("panel", header_style)
 main.root.add_child(header)
 var header_row := HBoxContainer.new()
 header_row.add_theme_constant_override("separation", 12)
 header.add_child(header_row)
 var art := TextureRect.new()
 art.texture = PlaySkin.game_cover(main.game)
 art.custom_minimum_size = Vector2(64, 64)
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 header_row.add_child(art)
 var titles := VBoxContainer.new()
 titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 titles.alignment = BoxContainer.ALIGNMENT_CENTER
 header_row.add_child(titles)
 var game_title := Label.new()
 game_title.text = main.game_title(main.game)
 game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 game_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 game_title.add_theme_font_size_override("font_size", int(23 * main.reading_scale))
 titles.add_child(game_title)
 var subtitle := Label.new()
 subtitle.text = main.tr_ui("إعدادات الجولة", "ROUND SETTINGS")
 subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 subtitle.add_theme_font_size_override("font_size", int(14 * main.reading_scale))
 subtitle.add_theme_color_override("font_color", Color("79dbff"))
 titles.add_child(subtitle)
 if main.game==0:picture_difficulty(main)
 else:selector(main,main.tr_ui("المستوى","Difficulty"),[1,2,3],[main.difficulty_name(1),main.difficulty_name(2),main.difficulty_name(3)],main.difficulty,func(value):main.difficulty=value)
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
  if main.game==1:cinema_topics(main,topics,captions)
  else:selector(main,main.tr_ui("الفئة","Category"),topics,captions,main.selected_topic,func(value):main.selected_topic=value)
  selector(main,main.tr_ui("طريقة الجولة","Round style"),["classic","survival","rival","blitz"],[main.tr_ui("كلاسيكي · بدون مؤقت","Classic · untimed"),main.tr_ui("البقاء · 3 محاولات","Survival · 3 lives"),main.tr_ui("سباق نقاط · منافس محلي","Score race · local rival"),main.tr_ui("سرعة · مؤقت حسب المستوى","Blitz · timed by difficulty")],main.match_style,func(value):main.match_style=value)
 else:
  selector(main,main.tr_ui("المغامرة","Adventure"),["island","archive"],[main.tr_ui("جزيرة المنارة","Lighthouse island"),main.tr_ui("أرشيف الأسرار","Secret archive")],main.selected_campaign,func(value):main.selected_campaign=value)
 main.label(main.tr_ui("الجولة حسب المحتوى المتاح في مجموعتك.","Rounds use available content in your collection."),14)
 main.button(main.tr_ui("▶  ابدأ اللعب","▶  LET’S PLAY"),func():main.quick_match_active=false;main.start_game(),main.GREEN if main.game == 0 else main.GOLD).set_meta("setup_action","start")
 main.button(main.tr_ui("خيارات لعب إضافية","More play options"),func():main._show_legacy_game_options(main.game),main.PANEL)
 main.button(main.tr_ui("اختيار النمط","Choose mode"),func():main.show_modes(main.game),main.PANEL)
