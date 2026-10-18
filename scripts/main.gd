extends Control

const VisualSkin = preload("res://scripts/visual_skin.gd")
const HomeLayoutCatalog = preload("res://scripts/home_layout_catalog.gd")

const AUDIENCES: Array[String] = ["all"]
var audience: String = "all"
# Neutral age-screen used only for ads and child protections; no birth date collected.
var age_group: String = "unknown"
var reading_scale: float = 1.0
var session_length: int = 15
var selected_topic: String = "all"
var family_active: bool = false
var family_ready: bool = false
var family_player: int = 0
var family_names: Array[String] = []
var family_scores: Array[int] = []
var family_fields: Array[LineEdit] = []
var family_size: int = 2
var family_all_ages: bool = true
var selection_notice: bool = false
var rival_personality: String = "analyst"
var rival_used_questions: Array[String] = []
var rival_turn_count: int = 0
# Competitive quiz modes are local and offline. Rival results are simulated, never real players.
var match_style: String = "classic"
var lives_left: int = 3
var opponent_points: int = 0
var opponent_skill: float = 0.65
var event_modifier: String = "normal"
var mode_finished_early: bool = false
var match_reward_committed: bool = false
# v10.7: Short opt-in arcade modes. Kept entirely offline; no ads or real-money rewards.
var blitz_timer: Timer
var blitz_meter: ProgressBar
var blitz_counter: Label
var blitz_duration: float = 0.0
var blitz_last_bonus: int = 0
var blitz_total_bonus: int = 0
var blitz_background_paused: bool = false
var blitz_dialog_paused: bool = false
var treasure_keys: int = 0
var treasure_shields: int = 0
var treasure_doubles: int = 0
var treasure_claims: int = 0
var treasure_latest_checkpoint: int = -1
var treasure_saved_streak: bool = false
var treasure_doubled_this_round: bool = false
var quick_match_active: bool = false
# v10.8: Push-your-luck challenge. Pending points are not spendable currency.
var vault_pending: int = 0
var vault_banked: int = 0
var vault_decisions: int = 0
var vault_lost: int = 0
var vault_locked: bool = false
# v11.0: offline championship — three five-question stages.
var championship_stage: int = 0
var championship_stage_scores: Array[int] = []
var championship_total_errors: int = 0


func profile_path() -> String:
 return "user://progress_v10_" + audience + ".json"

func load_audience_preferences() -> void:
 if FileAccess.file_exists("user://audience_preferences.json"):
  var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://audience_preferences.json"))
  if value is Dictionary:
   audience = str(value.get("audience", ""))
 audience = "all"

func select_audience(key: String) -> void:
 if key not in AUDIENCES:
  return
 if not audience.is_empty():
  save_progress()
 var requested_language: String = selected_language
 audience = key
 AdManager.set_audience("adults" if age_group == "18plus" else "children")
 var file := FileAccess.open("user://audience_preferences.json", FileAccess.WRITE)
 if file != null:
  file.store_string(JSON.stringify({"audience": audience}))
  file.close()
 profile = {"xp": 0, "wins": 0, "matches": 0, "picture_wins": 0}
 reading_scale = 1.25 if key in ["children", "adults"] else 1.0
 session_length = 10 if key == "children" else (20 if key == "youth" else 15)
 difficulty = 1 if key in ["children", "family"] else 2
 selected_topic = "all"
 family_active = false
 load_upgrade()
 selected_language = requested_language
 save_progress()
 show_home()

func audience_title(key: String = "") -> String:
 if key.is_empty():
  key = audience
 var ar: Array[String] = ["الأطفال", "المراهقون", "الشباب", "الكبار", "العائلات"]
 var en: Array[String] = ["CHILDREN", "TEENS", "YOUNG ADULTS", "ADULTS", "FAMILIES"]
 var index: int = AUDIENCES.find(key)
 return tr_ui(ar[index], en[index]) if index >= 0 else tr_ui("اختر تجربتك", "CHOOSE YOUR EXPERIENCE")

func audience_description(key: String = "") -> String:
 if key.is_empty():
  key = audience
 var ar: Array[String] = ["أسئلة قصيرة، اختيارات واضحة، وجلسات لطيفة دون ضغط وقت", "استكشاف اللغة والمنطق والمعرفة مع تحديات متدرجة", "جلسات أطول، تحديات متنوعة، ومستوى متقدم متاح", "قراءة أكبر افتراضيًا، وتيرة هادئة، وكل مستويات التحدي متاحة", "تعاون وتحديات بالتناوب على جهاز واحد، مع أسماء ونقاط لكل لاعب"]
 var en: Array[String] = ["Short questions, clear choices and gentle untimed sessions", "Explore language, logic and knowledge with graduated challenges", "Longer sessions, varied challenges and advanced levels", "Larger default text, relaxed pacing and every difficulty level", "Shared-device turn play with player names and scores"]
 var index: int = AUDIENCES.find(key)
 return tr_ui(ar[index], en[index]) if index >= 0 else ""

func show_audiences() -> void:
 clear_ui()
 label(tr_ui("تجربة تناسبك", "AN EXPERIENCE FOR YOU"), 32)
 button("العربية / English", show_languages)
 label(tr_ui("لكل فئة تقدم مستقل على هذا الجهاز", "Each audience has separate progress on this device"), 18)
 for key in AUDIENCES:
  var chosen: String = key
  button(audience_title(key), func(): select_audience(chosen), GREEN if key == audience else PANEL)
  label(audience_description(key), 17)
 label(tr_ui("الأطفال: 6–12 والمراهقون: 13–17 كتقسيم مبدئي قابل للتعديل", "Children: 6–12; teens: 13–17 as adjustable starting groups"), 14)

func show_accessibility() -> void:
 clear_ui()
 label(tr_ui("القراءة ومدة الجلسة", "READING AND SESSION LENGTH"), 29)
 label(tr_ui("حجم النص", "TEXT SIZE"), 22)
 for scale_value in [1.0, 1.25, 1.5]:
  var chosen: float = float(scale_value)
  button("%d%%" % int(chosen * 100), func(): reading_scale = chosen; save_progress(); show_accessibility(), GREEN if is_equal_approx(chosen, reading_scale) else PANEL)
 label(tr_ui("الحد الأقصى لأسئلة الجلسة", "MAX QUESTIONS PER SESSION"), 22)
 for length_value in [10, 15, 20, 50, 100, 150]:
  var chosen: int = int(length_value)
  button(str(chosen), func(): session_length = chosen; save_progress(); show_accessibility(), GREEN if chosen == session_length else PANEL)
 label(tr_ui("الصوت والمؤثرات", "SOUND & EFFECTS"), 22)
 button(tr_ui("📳 اهتزاز اللمس: يعمل", "📳 TOUCH FEEDBACK: ON") if haptics_enabled else tr_ui("📳 اهتزاز اللمس: مغلق", "📳 TOUCH FEEDBACK: OFF"), func(): haptics_enabled = not haptics_enabled; save_progress(); show_accessibility(), GREEN if haptics_enabled else PANEL)
 button(tr_ui("🔊 الصوت: يعمل", "🔊 SOUND: ON") if sound_enabled else tr_ui("🔇 الصوت: مغلق", "🔇 SOUND: OFF"), func(): sound_enabled = not sound_enabled; save_progress(); show_accessibility(), GREEN if sound_enabled else PANEL)
 button(tr_ui("✨ الحركة: خفيفة", "✨ MOTION: REDUCED") if reduced_motion else tr_ui("✨ الحركة: عادية", "✨ MOTION: NORMAL"), func(): reduced_motion = not reduced_motion; save_progress(); show_accessibility(), GREEN if reduced_motion else PANEL)
 label(tr_ui("إيقاف الحركة يقلل التحريك الزائد؛ الأصوات قصيرة ويمكن إيقافها.", "Reduced motion limits UI animation; short sounds can be muted."), 16)
 label(tr_ui("يمكن تعديل القراءة دون تغيير مستوى الصعوبة", "Reading size is independent of difficulty"), 17)
 button(tr_ui("العودة", "BACK"), show_home, ACCENT)

func eligible_questions(index: int, use_topic: bool = true) -> Array:
 var result: Array = []
 for item in question_bank.get(str(index), []):
  # Everyone plays the same challenge ladder. Hide elementary recognition prompts.
  if str(item.get("id", "")).begins_with("visual_v36_"):
   continue
  if not use_topic or selected_topic == "all" or str(item.get("topic", "")) == selected_topic:
   result.append(item)
 return result

func topic_title(key: String) -> String:
 var ar: Dictionary = {"all": "كل الموضوعات", "cinema": "قصص السينما", "craft": "صناعة الأفلام", "language": "اللغة", "logic": "التفكير المنطقي", "numbers": "الأرقام والحساب", "math": "رياضيات وتفكير", "adventure": "المغامرة", "science": "العلوم", "nature": "الطبيعة", "space": "الفضاء", "geography": "الجغرافيا", "audio": "الأصوات", "deduction": "الاستنتاج", "order": "ترتيب الخطوات", "visual": "استكشف الصور"}
 var en: Dictionary = {"all": "All topics", "cinema": "Film stories", "craft": "Film craft", "language": "Language", "logic": "Logic", "numbers": "Numbers", "math": "Math & puzzles", "adventure": "Adventure", "science": "Science", "nature": "Nature", "space": "Space", "geography": "Geography", "audio": "Sounds", "deduction": "Deduction", "order": "Step ordering", "visual": "Picture explorer"}
 return tr_ui(str(ar.get(key, key)), str(en.get(key, key)))

func show_topics() -> void:
 clear_ui()
 label(tr_ui("اختر الموضوع", "CHOOSE A TOPIC"), 28)
 var topics: Array[String] = ["all"]
 for item in eligible_questions(game, false):
  var key: String = str(item.get("topic", ""))
  if key not in topics:
   topics.append(key)
 for key in topics:
  var chosen: String = key
  button(topic_title(key), func(): selected_topic = chosen; show_modes(game), GREEN if key == selected_topic else PANEL)

func show_family_setup() -> void:
 clear_ui()
 label(tr_ui("ليلة الألعاب العائلية", "FAMILY GAME NIGHT"), 30)
 label(tr_ui("مرر الجهاز إلى اللاعب التالي عند شاشة الاستعداد", "Pass the device to the next player at the ready screen"), 18)
 button(tr_ui("المحتوى: ", "CONTENT: ") + (tr_ui("مناسب للأصغر • اضغط للتغيير", "Younger players • tap to switch") if family_all_ages else tr_ui("متنوع • اضغط للتغيير", "Mixed • tap to switch")), func(): family_all_ages = not family_all_ages; show_family_setup())
 for count in [2, 3, 4]:
  var chosen: int = int(count)
  button(tr_ui("%d لاعبين", "%d players") % chosen, func(): family_size = chosen; show_family_setup(), GREEN if family_size == chosen else PANEL)
 family_fields.clear()
 for i in range(family_size):
  var field := LineEdit.new()
  field.text = tr_ui("لاعب %d", "Player %d") % (i + 1)
  field.max_length = 24
  field.custom_minimum_size.y = 58
  root.add_child(field)
  family_fields.append(field)
 button(tr_ui("ابدأ اللعب العائلي", "START FAMILY PLAY"), prepare_family, GREEN)
 button(tr_ui("العودة", "BACK"), func(): show_modes(game), ACCENT)

func prepare_family() -> void:
 family_names.clear()
 for i in range(family_fields.size()):
  var value: String = family_fields[i].text.strip_edges()
  family_names.append(value if not value.is_empty() else tr_ui("لاعب %d", "Player %d") % (i + 1))
 start_family_match()

func start_family_match() -> void:
 session_best_streak = 0
 session_mistakes = 0
 campaign_active = false
 if family_names.size() < 2:
  show_family_setup()
  return
 family_active = true
 daily_match = false
 family_ready = false
 family_player = 0
 family_scores.clear()
 for _name in family_names:
  family_scores.append(0)
 question_index = 0
 score = 0
 streak = 0
 correct_count = 0
 round_bank = eligible_questions(game).duplicate(true)
 shuffle_items(round_bank)
 var count: int = mini(round_bank.size(), session_length * family_names.size())
 count -= count % family_names.size()
 if count == 0:
  round_bank = eligible_questions(game, false).duplicate(true)
  shuffle_items(round_bank)
  count = mini(round_bank.size(), session_length * family_names.size())
  count -= count % family_names.size()
 round_bank = round_bank.slice(0, count)
 if count == 0:
  family_active = false
  show_modes(game)
  return
 show_round()

func show_family_handover() -> void:
 clear_ui()
 label(tr_ui("مرر الجهاز", "PASS THE DEVICE"), 32)
 label(family_names[family_player], 34)
 label(tr_ui("السؤال مخفي حتى تكون مستعدًا", "The question stays hidden until you are ready"), 19)
 button(tr_ui("أنا مستعد", "I AM READY"), func(): family_ready = true; show_round(), GREEN)
 button(tr_ui("إنهاء اللعب", "END GAME"), func(): show_modes(game))

var ui_tr: Dictionary = {}
var question_bank: Dictionary = {}
var round_bank: Array = []
var profile: Dictionary = {"xp": 0, "wins": 0, "matches": 0, "picture_wins": 0}
var difficulty: int = 2
var streak: int = 0
var session_best_streak: int = 0
var session_mistakes: int = 0
var correct_count: int = 0
var hint_used: bool = false
var clue_index: int = 0
var daily_match: bool = false
var hint_button: Button
var hint_label: Label
var clue_button: Button
var clue_label: Label
var audio_player: AudioStreamPlayer
var last_reward: int = 0
var last_match_won: bool = false
var save_warning: bool = false
var picture_recorded: bool = false
var picture_question_page: int = 0
var art_style: String = "realistic"
var sound_enabled: bool = true
var haptics_enabled: bool = true
var reduced_motion: bool = false
# The Android Back key must never silently discard an active round.
var active_play_screen: bool = false
# A small LRU prevents repeat disk loads during card flips and screen transitions.
# Unlike a global preload of every card, the cache holds at most 10 textures.
const TEXTURE_CACHE_LIMIT: int = 10
var texture_cache: Dictionary = {}
var texture_cache_order: Array[String] = []

func cached_texture(path: String) -> Texture2D:
 if path.is_empty() or not path.begins_with("res://assets/"):
  return null
 if texture_cache.has(path):
  texture_cache_order.erase(path)
  texture_cache_order.append(path)
  return texture_cache[path] as Texture2D
 if not ResourceLoader.exists(path):
  return null
 var texture: Texture2D = load(path) as Texture2D
 if texture == null:
  return null
 texture_cache[path] = texture
 texture_cache_order.append(path)
 while texture_cache_order.size() > TEXTURE_CACHE_LIMIT:
  var oldest: String = texture_cache_order.pop_front()
  texture_cache.erase(oldest)
 return texture

func xp_progress() -> void:
 var total_xp: int = maxi(0, int(profile.get("xp", 0)))
 var level: int = 1 + floori(float(total_xp) / 100.0)
 var remaining: int = total_xp % 100
 label(tr_ui("المستوى %d • %d / 100 XP للمستوى التالي", "LEVEL %d • %d / 100 XP TO NEXT LEVEL") % [level, remaining], 18)
 var progress := ProgressBar.new()
 progress.min_value = 0.0
 progress.max_value = 100.0
 progress.value = float(remaining)
 progress.show_percentage = false
 progress.custom_minimum_size.y = 18
 VisualSkin.decorate_progress(progress, true)
 progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 root.add_child(progress)

# Lightweight, reusable native Godot UI: no particle nodes or expensive shaders.
# Uses two equal-width tiles so text remains readable in portrait orientation.
func stat_strip(left_title: String, left_value: String, right_title: String, right_value: String) -> void:
 var strip := HBoxContainer.new()
 strip.add_theme_constant_override("separation", 10)
 strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 root.add_child(strip)
 for entry in [[left_title, left_value], [right_title, right_value]]:
  var tile := PanelContainer.new()
  tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  tile.size_flags_stretch_ratio = 1.0
  tile.add_theme_stylebox_override("panel", panel_style(Color("172c55")))
  strip.add_child(tile)
  var content := VBoxContainer.new()
  content.add_theme_constant_override("separation", 4)
  tile.add_child(content)
  var value_label := Label.new()
  value_label.text = str(entry[1])
  value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  value_label.add_theme_font_size_override("font_size", int(25 * reading_scale))
  value_label.add_theme_color_override("font_color", Color("ffe19a"))
  content.add_child(value_label)
  var title_label := Label.new()
  title_label.text = str(entry[0])
  title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  title_label.add_theme_font_size_override("font_size", int(14 * reading_scale))
  title_label.add_theme_color_override("font_color", Color("d6e6ff"))
  content.add_child(title_label)

# Non-blocking native confetti. Disabled for reduced-motion accessibility.
func show_celebration(grand: bool) -> void:
 if reduced_motion:
  return
 var fx := preload("res://scripts/celebration_fx.gd").new()
 fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
 fx.intensity = 1.0 if grand else 0.55
 add_child(fx)

func result_hero(accuracy: int) -> void:
 var frame := PanelContainer.new()
 frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 frame.add_theme_stylebox_override("panel", panel_style(Color("194e51") if last_match_won else Color("263456")))
 root.add_child(frame)
 var content := VBoxContainer.new()
 content.add_theme_constant_override("separation", 8)
 frame.add_child(content)
 var heading := Label.new()
 heading.text = tr_ui("🎉 فوز مستحق!" if last_match_won else "🌟 الجولة انتهت", "🎉 YOU WON!" if last_match_won else "🌟 ROUND COMPLETE")
 heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 heading.add_theme_font_size_override("font_size", int(28 * reading_scale))
 heading.add_theme_color_override("font_color", Color.WHITE)
 content.add_child(heading)
 var medal := Label.new()
 medal.text = result_medal(accuracy)
 medal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 medal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 medal.add_theme_font_size_override("font_size", int(21 * reading_scale))
 medal.add_theme_color_override("font_color", Color("ffe19a"))
 content.add_child(medal)
 if not reduced_motion:
  frame.modulate.a = 0.0
  frame.create_tween().tween_property(frame, "modulate:a", 1.0, 0.22)

func result_medal(accuracy: int) -> String:
 if accuracy >= 95:
  return tr_ui("🏆 ذهبي • إتقان رائع", "🏆 GOLD • OUTSTANDING")
 if accuracy >= 80:
  return tr_ui("🥈 فضي • أداء قوي", "🥈 SILVER • STRONG PLAY")
 if accuracy >= 60:
  return tr_ui("🥉 برونزي • تقدم ممتاز", "🥉 BRONZE • NICE PROGRESS")
 return tr_ui("🎯 استمر في التدريب", "🎯 KEEP PRACTICING")


func load_upgrade() -> void:
 ui_tr = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_tr.json"))
 load_catalog()
 load_audience_preferences()
 reading_scale = 1.25 if audience in ["children", "adults"] else 1.0
 session_length = 150
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
 if parsed is Dictionary:
  question_bank = parsed
 apply_daily_rounds()
 if FileAccess.file_exists(profile_path()):
  var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_path()))
  if saved is Dictionary:
   profile.merge(saved, true)
 reading_scale = clampf(float(profile.get("reading_scale", reading_scale)), 1.0, 1.5)
 if int(profile.get("session_version", 0)) < 15:
  session_length = maxi(session_length, int(profile.get("session_length", session_length)))
 else:
  session_length = int(profile.get("session_length", session_length))
 session_length = clampi(session_length, 10, 150)
 difficulty = clampi(int(profile.get("difficulty", 2)), 1, 3)
 family_all_ages = bool(profile.get("family_all_ages", true))
 selected_language = str(profile.get("language", "ar"))
 art_style = str(profile.get("art_style", "realistic"))
 sound_enabled = bool(profile.get("sound_enabled", true))
 haptics_enabled = bool(profile.get("haptics_enabled", true))
 reduced_motion = bool(profile.get("reduced_motion", false))
 selected_campaign = str(profile.get("selected_campaign", "island"))
 if selected_campaign not in ["island", "archive"]:
  selected_campaign = "island"
 if selected_language not in ["ar", "en"]:
  selected_language = "ar"

# The bundled catalog remains the authoritative offline fallback. Network content only
# extends the three supported game pools after strict validation in DailyRounds.
func apply_daily_rounds() -> void:
 # Rebuild a newest-first combined catalog from durable history + original questions.
 # Never remove historical packs just because today changed.
 for key in ["2", "3", "5"]:
  var bundled: Array = []
  var seen: Dictionary = {}
  for question in question_bank.get(key, []):
   if not str(question.get("id", "")).begins_with("remote_"):
    bundled.append(question)
    seen[str(question.get("id", ""))] = true
  var combined: Array = []
  for daily_pack in DailyRounds.history:
   for question in daily_pack.get("questions", []):
    if str(question.get("game", "")) != key:
     continue
    var identity: String = str(question.get("id", ""))
    if not seen.has(identity):
     var copy: Dictionary = question.duplicate(true)
     copy.erase("game")
     combined.append(copy)
     seen[identity] = true
  combined.append_array(bundled)
  question_bank[key] = combined

func _on_daily_rounds_changed() -> void:
 apply_daily_rounds()

func save_progress() -> void:
 if audience.is_empty():
  return
 profile["language"] = selected_language
 profile["art_style"] = art_style
 profile["sound_enabled"] = sound_enabled
 profile["haptics_enabled"] = haptics_enabled
 profile["reduced_motion"] = reduced_motion
 profile["reading_scale"] = reading_scale
 profile["session_length"] = session_length
 profile["session_version"] = 15
 profile["difficulty"] = difficulty
 profile["family_all_ages"] = family_all_ages
 profile["selected_campaign"] = selected_campaign
 var file := FileAccess.open(profile_path(), FileAccess.WRITE)
 if file != null:
  file.store_string(JSON.stringify(profile))
  save_warning = false
 else:
  save_warning = true

func panel_style(color: Color) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = color
 style.set_corner_radius_all(18)
 style.border_color = color.lightened(0.18)
 style.set_border_width_all(2)
 style.content_margin_left = 12
 style.content_margin_right = 12
 style.content_margin_top = 12
 style.content_margin_bottom = 12
 return style

func game_subtitle(index: int) -> String:
 var ar: Array[String] = ["استنتاج وأسئلة ذكية", "قصص وأسرار صناعة السينما", "رتب واكتب واستكشف اللغة", "منطق وأنماط واحتمالات", "قصة متعددة الفصول", "علم وجغرافيا ومعرفة", "استمع وميّز الإيقاع", "أدلة تتكشف خطوة بخطوة", "طابق الصور ودرب ذاكرتك", "رتب الخطوات والأحداث"]
 var en: Array[String] = ["Deduction and smart questions", "Stories and film craft", "Unscramble and explore language", "Logic, patterns and probability", "A multi-chapter story", "Science, geography and knowledge", "Listen and identify patterns", "Clues revealed step by step", "Match pictures and train your memory", "Order steps and events"]
 return tr_ui(ar[index], en[index])

func difficulty_name(level: int) -> String:
 var ar: Array[String] = ["سهل • بداية الرحلة", "متوسط • تحدٍ أقوى", "صعب • للمتمرسين"]
 var en: Array[String] = ["EASY • warm up", "MEDIUM • challenge", "HARD • expert"]
 return tr_ui(ar[level - 1], en[level - 1])

func shuffle_items(items: Array) -> void:
 for i in range(items.size() - 1, 0, -1):
  var j: int = rng.randi_range(0, i)
  var temp: Variant = items[i]
  items[i] = items[j]
  items[j] = temp

func normal_answer(value: String) -> String:
 var normalized: String = value.strip_edges().to_lower()
 for mark in ["َ", "ً", "ُ", "ٌ", "ِ", "ٍ", "ْ", "ّ", "ـ"]:
  normalized = normalized.replace(mark, "")
 normalized = normalized.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ى", "ي")
 if normalized.begins_with("ال"):
  normalized = normalized.substr(2)
 normalized = normalized.replace("̇", "").replace("ı", "i").replace("İ", "i").replace("ş", "s").replace("ç", "c").replace("ğ", "g").replace("ü", "u").replace("ö", "o")
 return normalized.replace(" ", "").replace("-", "").replace(".", "").replace("_", "")

func submit_written(value: String) -> void:
 if round_finished:
  return
 if value.strip_edges().is_empty():
  return
 var item: Dictionary = round_bank[question_index]
 var answers: Array = item["answers_" + selected_language]
 var correct: bool = false
 var accepted: Array = item["answers_ar"] + item["answers_en"] + item.get("answers_tr", [])
 for answer in accepted:
  if normal_answer(value) == normal_answer(str(answer)):
   correct = true
 finish_round(correct, str(answers[0]))

func reveal_clue() -> void:
 var item: Dictionary = round_bank[question_index]
 var clues: Array = item["clues_" + selected_language]
 if clue_index + 1 >= clues.size():
  return
 clue_index += 1
 clue_label.text += "\n\n" + str(clues[clue_index])
 clue_button.disabled = clue_index + 1 >= clues.size()

func show_hint() -> void:
 if hint_used:
  return
 hint_used = true
 hint_button.disabled = true
 var item: Dictionary = round_bank[question_index]
 var key: String = "hint_" + selected_language
 if item.has(key):
  hint_label.text = str(item[key])
 else:
  var choices: Array = item["choices_" + selected_language]
  var correct: int = int(item["correct"])
  var alternate: int = (correct + 1) % choices.size()
  hint_label.text = tr_ui("الإجابة واحدة من: ", "One of these: ") + str(choices[correct]) + " / " + str(choices[alternate]) if rng.randf() < 0.5 else tr_ui("الإجابة واحدة من: ", "One of these: ") + str(choices[alternate]) + " / " + str(choices[correct])

func play_clip(id: String) -> void:
 stop_audio()
 audio_player = AudioStreamPlayer.new()
 audio_player.stream = load("res://assets/audio/" + id + ".wav")
 audio_player.volume_db = -8
 add_child(audio_player)
 audio_player.play()

# Short original feedback tones, generated offline and bundled locally.
# Never loads remote audio or blocks the main thread waiting for network.
func play_tap() -> void:
 var tap_path: String = "res://assets/audio/ui_tap.wav"
 if not ResourceLoader.exists(tap_path):
  return
 var tap_player := AudioStreamPlayer.new()
 tap_player.stream = load(tap_path)
 tap_player.volume_db = -21.0
 add_child(tap_player)
 tap_player.finished.connect(tap_player.queue_free)
 tap_player.play()

func play_feedback(effect: String) -> void:
 if not sound_enabled:
  return
 if effect not in ["success", "celebrate", "retry"]:
  return
 var path: String = "res://assets/audio/feedback_" + effect + ".wav"
 if not ResourceLoader.exists(path):
  return
 var player := AudioStreamPlayer.new()
 player.stream = load(path)
 player.volume_db = -13.0
 add_child(player)
 player.finished.connect(player.queue_free)
 player.play()

func stop_audio() -> void:
 if is_instance_valid(audio_player):
  audio_player.stop()
  audio_player.queue_free()
 audio_player = null

func finish_match() -> void:
 if match_style == "vault" and not family_active and not campaign_active and not daily_match and vault_pending > 0:
  vault_banked += vault_pending
  score += vault_pending
  vault_pending = 0
 if match_reward_committed:
  return
 match_reward_committed = true
 # Local-only achievements; each achievement awards XP only once.
 if not family_active and not campaign_active and not daily_match:
  var achievements: Dictionary = profile.get("arcade_achievements", {})
  var earned_achievements: Array[String] = []
  if session_best_streak >= 5 and not bool(achievements.get("streak_5", false)):
   earned_achievements.append("streak_5")
  if session_best_streak >= 10 and not bool(achievements.get("streak_10", false)):
   earned_achievements.append("streak_10")
  if match_style == "vault" and vault_decisions >= 2 and vault_lost == 0 and not bool(achievements.get("vault_master", false)):
   earned_achievements.append("vault_master")
  for achievement in earned_achievements:
   achievements[achievement] = true
  profile["arcade_achievements"] = achievements
  profile["xp"] = int(profile.get("xp", 0)) + earned_achievements.size() * 75
  profile["arcade_new_achievements"] = earned_achievements
 var completed: int = question_index + 1 if mode_finished_early else round_bank.size()
 var won: bool = correct_count * 2 > completed
 if match_style == "rival" and not family_active and not campaign_active and not daily_match:
  won = score > opponent_points
 if match_style == "championship" and not family_active and not campaign_active and not daily_match:
  won = not mode_finished_early and completed >= 15 and lives_left > 0
  if won:
   profile["championship_titles"] = int(profile.get("championship_titles", 0)) + 1
  profile["championship_best"] = maxi(int(profile.get("championship_best", 0)), score)
 if mode_finished_early:
  won = false
 if match_style == "treasure" and not campaign_active and not family_active and not daily_match:
  profile["treasure_chests"] = int(profile.get("treasure_chests", 0)) + treasure_claims
 if match_style == "blitz" and not campaign_active and not family_active and not daily_match:
  profile["best_blitz_bonus"] = maxi(int(profile.get("best_blitz_bonus", 0)), blitz_total_bonus)
 last_match_won = won
 last_reward = score + (20 if won else 5)
 LiveOps.update(profile, won)
 profile["matches"] = int(profile.get("matches", 0)) + 1
 profile["xp"] = int(profile.get("xp", 0)) + last_reward
 if completed > 0:
  var accuracy: int = roundi(100.0 * correct_count / completed)
  var accuracy_key: String = "best_accuracy_" + str(game)
  profile[accuracy_key] = maxi(int(profile.get(accuracy_key, 0)), accuracy)
 if won:
  profile["wins"] = int(profile.get("wins", 0)) + 1
 var key: String = "best_daily" if daily_match else "best_" + str(game)
 profile[key] = maxi(int(profile.get(key, 0)), score)
 if daily_match:
  var date: String = Time.get_date_string_from_system()
  var daily_key: String = "daily_" + date
  if profile.has(daily_key):
   if won:
    profile["wins"] = maxi(0, int(profile["wins"]) - 1)
   profile["xp"] = int(profile["xp"]) - last_reward
   last_reward = 0
  else:
   profile[daily_key] = true
 save_progress()

func claim_liveops(period: String, mission: Dictionary) -> void:
 if LiveOps.claim(profile, period, mission):
  save_progress()
 show_liveops()

func show_liveops() -> void:
 clear_ui()
 label(tr_ui("مغامرات لا تنتهي", "ENDLESS ADVENTURES"), 32)
 var event: Dictionary = LiveOps.event_for_week()
 label(str(event.get("ar", "حدث جديد كل أسبوع")) if selected_language == "ar" else str(event.get("en", "A new event every week")), 24)
 label(tr_ui("تحديات متجددة ومكافآت خبرة مجانية", "Rotating missions and free XP rewards"), 17)
 for period in ["daily", "weekly"]:
  label(tr_ui("مهام اليوم" if period == "daily" else "مهام الأسبوع", "DAILY MISSIONS" if period == "daily" else "WEEKLY MISSIONS"), 24)
  var record: Dictionary = profile.get("liveops_" + period, {})
  var key: String = LiveOps.day_key() if period == "daily" else LiveOps.week_key()
  if str(record.get("key", "")) != key:
   record = {}
  for mission in LiveOps.missions(period):
   var m: Dictionary = mission
   var stat: String = str(m.get("type", "matches"))
   var value: int = int(record.get(stat, 0))
   var target: int = int(m.get("target", 1))
   var done: bool = str(m.get("id", "")) in record.get("claimed", [])
   var title_text: String = tr_ui("افز" if stat == "wins" else "العب", "Win" if stat == "wins" else "Play") + " %d " % target + tr_ui("مباريات", "matches")
   label(title_text + "  •  %d/%d  •  +%d XP" % [mini(value, target), target, int(m.get("xp", 0))], 17)
   if done:
    label(tr_ui("تم استلام المكافأة ✓", "Reward claimed ✓"), 16)
   elif value >= target:
    button(tr_ui("استلم المكافأة", "CLAIM REWARD"), func(): claim_liveops(period, m), GREEN)
 button(tr_ui("العودة", "BACK"), show_home, ACCENT)

func show_results() -> void:
 clear_ui()
 play_feedback("celebrate" if last_match_won else "retry")
 label(tr_ui("🏆 حصيلة التحدي", "🏆 CHALLENGE RESULTS"), 32)
 if not family_active and not campaign_active and not daily_match:
  var stage_number: int = int(profile.get("journey_selected_stage", 1))
  label(journey_world_name(clampi((stage_number - 1) / 12, 0, JOURNEY_WORLDS.size() - 1)), 23)
 if not family_active and not campaign_active and not daily_match:
  label(tr_ui("🏁 نتائج المرحلة %d", "🏁 STAGE %d RESULTS") % int(profile.get("journey_selected_stage", 1)), 23)
 if not family_active and not campaign_active and not daily_match:
  label(match_style_name(), 20)
  if match_style == "championship":
   label(tr_ui("🏆 مراحل: %d/3 • محاولات متبقية: %d", "🏆 STAGES: %d/3 • LIVES LEFT: %d") % [mini(3, 1 + floori(float(question_index) / 5.0)), lives_left], 21)
   label(tr_ui("🏅 ألقاب البطولة: %d • أفضل نتيجة: %d", "🏅 TITLES: %d • BEST SCORE: %d") % [int(profile.get("championship_titles", 0)), int(profile.get("championship_best", 0))], 19)
  if match_style == "rival":
   label(tr_ui("نقاطك: %d • نقاط المنافس: %d", "YOUR SCORE: %d • RIVAL: %d") % [score, opponent_points], 22)
   label(tr_ui("فزت بالسباق!" if score > opponent_points else "تعادل!" if score == opponent_points else "المنافس فاز، جرّب مرة ثانية", "YOU WON!" if score > opponent_points else "DRAW!" if score == opponent_points else "RIVAL WON — TRY AGAIN"), 20)
  if match_style == "blitz":
   label(tr_ui("⚡ مجموع مكافآت السرعة: %d", "⚡ TOTAL SPEED BONUS: %d") % blitz_total_bonus, 21)
  if match_style == "vault":
   label(tr_ui("💎 نقاط محفوظة: %d • نقاط خسرتها: %d • قرارات: %d", "💎 BANKED: %d • LOST: %d • DECISIONS: %d") % [vault_banked, vault_lost, vault_decisions], 20)
  if match_style == "treasure":
   label(tr_ui("🎁 صناديق مفتوحة: %d • مفاتيح متبقية: %d", "🎁 CHESTS OPENED: %d • KEYS LEFT: %d") % [treasure_claims, treasure_keys], 21)
  if mode_finished_early:
   label(tr_ui("انتهت محاولات البقاء", "SURVIVAL RUN ENDED"), 20)

 if campaign_active and selected_campaign == "island":
  campaign_scene(4, 210)
  label(tr_ui("عادت إشارة المنارة • اكتملت قطع الخريطة الخمس", "THE LIGHTHOUSE RETURNS • ALL FIVE MAP PIECES FOUND"), 24)
 if family_active:
  for i in range(family_names.size()):
   label(family_names[i] + " • " + str(family_scores[i]), 24)
 var attempted: int = question_index + 1 if mode_finished_early else round_bank.size()
 var final_accuracy: int = roundi(100.0 * correct_count / maxi(1, attempted))
 result_hero(final_accuracy)
 if last_match_won:
  show_celebration(true)
 stat_strip(tr_ui("إجابات صحيحة", "CORRECT ANSWERS"), "%d / %d" % [correct_count, attempted], tr_ui("الدقة", "ACCURACY"), "%d%%" % final_accuracy)
 if round_bank.size() > 0:
  var accuracy: int = roundi(100.0 * correct_count / maxi(1, attempted))
  label(tr_ui("الدقة: %d%%  •  أفضل سلسلة: %d", "Accuracy: %d%%  •  Best streak: %d") % [accuracy, session_best_streak], 20)
  if not family_active:
   label(tr_ui("أفضل دقة سابقة: %d%%", "BEST ACCURACY: %d%%") % int(profile.get("best_accuracy_" + str(game), accuracy)), 17)
  if session_mistakes > 0 and not family_active:
   label(tr_ui("عندك %d إجابات للمراجعة. جرّب تراجعها لتحسن مستواك.", "You have %d answers to revisit. Practice them to improve.") % session_mistakes, 17)
   button(tr_ui("تدريب على أخطائي", "PRACTICE MY MISTAKES"), start_review, ACCENT)
 label(tr_ui("%d نقطة  •  +%d خبرة", "%d points  •  +%d XP") % [score, last_reward], 22)
 xp_progress()
 if not family_active and not campaign_active and not daily_match:
  var achievement_names: Dictionary = {
   "streak_5": tr_ui("🔥 سلسلة 5 إجابات", "🔥 FIVE-IN-A-ROW"),
   "streak_10": tr_ui("🏆 سلسلة 10 إجابات", "🏆 TEN-IN-A-ROW"),
   "vault_master": tr_ui("💎 سيد الخزنة", "💎 VAULT MASTER")
  }
  for unlocked in profile.get("arcade_new_achievements", []):
   label(tr_ui("🎖 إنجاز جديد: ", "🎖 NEW ACHIEVEMENT: ") + str(achievement_names.get(str(unlocked), str(unlocked))) + "  +75 XP", 19)
 if daily_match and last_reward == 0:
  label(tr_ui("جمعت مكافأة اليوم بالفعل؛ يمكنك الاستمرار للتدريب", "Today’s reward was already collected; replay for practice"), 16)
 if save_warning:
  label(tr_ui("تعذر حفظ التقدم على الجهاز", "Progress could not be saved on this device"), 16)
 if not family_active and not campaign_active and not daily_match:
  var pass_score: bool = attempted > 0 and correct_count * 100 >= attempted * 60
  var selected_stage: int = int(profile.get("journey_selected_stage", 1))
  var frontier: int = 1 + int(profile.get("challenge_stage", 0))
  if pass_score and selected_stage == frontier and frontier < JOURNEY_STAGE_COUNT:
   label(tr_ui("⭐ ممتاز! فتحت المرحلة التالية", "⭐ GREAT! NEXT STAGE UNLOCKED"), 20)
   button(tr_ui("🚀 افتح المرحلة التالية", "🚀 UNLOCK NEXT STAGE"), advance_challenge_stage, GOLD)
  elif not pass_score:
   label(tr_ui("محتاج 60%% إجابات صحيحة لفتح المرحلة التالية", "SCORE 60%% CORRECT TO UNLOCK THE NEXT STAGE"), 18)
  elif selected_stage < frontier:
   label(tr_ui("مرحلة معادة • تقدمك محفوظ", "REPLAYED STAGE • PROGRESS SAVED"), 18)
 if not family_active and not campaign_active and not daily_match:
  button(tr_ui("🗺 خريطة العوالم", "🗺 WORLD MAP"), show_journey_map, ACCENT)
 button(tr_ui("تحدٍ جديد", "PLAY AGAIN"), start_family_match if family_active else (start_daily if daily_match else (start_quick_match if quick_match_active else start_game)), GREEN)
 button(tr_ui("قائمة الألعاب", "GAMES MENU"), show_home, ACCENT)

func advance_challenge_stage() -> void:
 if int(profile.get("journey_selected_stage", 1)) != 1 + int(profile.get("challenge_stage", 0)):
  return
 profile["challenge_stage"] = mini(JOURNEY_STAGE_COUNT - 1, int(profile.get("challenge_stage", 0)) + 1)
 profile["journey_selected_stage"] = 1 + int(profile["challenge_stage"])
 difficulty = mini(3, 1 + floori(float(profile["challenge_stage"]) / 12.0))
 save_progress()
 launch_journey_stage(int(profile["journey_selected_stage"]))

func show_achievements() -> void:
 clear_ui()
 label(tr_ui("رحلتك في Gaming Hub", "YOUR GAMING HUB JOURNEY"), 29)
 var matches: int = int(profile.get("matches", 0))
 var wins: int = int(profile.get("wins", 0))
 var picture_wins: int = int(profile.get("picture_wins", 0))
 for item in [[tr_ui("الخطوة الأولى", "FIRST STEP"), matches >= 1], [tr_ui("خمسة تحديات", "FIVE CHALLENGES"), matches >= 5], [tr_ui("ثلاثة انتصارات", "THREE WINS"), wins >= 3], [tr_ui("المحقق", "DETECTIVE"), picture_wins >= 1], [tr_ui("1000 نقطة خبرة", "1000 XP"), int(profile.get("xp", 0)) >= 1000]]:
  label(("✓ " if bool(item[1]) else "○ ") + str(item[0]), 22)
 for i in range(GAMES.size()):
  label(game_title(i) + " • " + str(profile.get("best_" + str(i), 0)), 17)
 label(tr_ui("🏆 ألقاب البطولة: %d", "🏆 CHAMPIONSHIP TITLES: %d") % int(profile.get("championship_titles", 0)), 20)
 button(tr_ui("العودة", "BACK"), show_home, ACCENT)

func start_daily() -> void:
 quick_match_active = false
 campaign_active = false
 family_active = false
 daily_match = true
 game = 5
 difficulty = 2
 question_index = 0
 score = 0
 streak = 0
 correct_count = 0
 session_best_streak = 0
 session_mistakes = 0
 round_bank.clear()
 var pool: Array = []
 for key in ["1", "3", "5", "7"]:
  for item in eligible_questions(int(key), false):
   pool.append(item.duplicate(true))
 var daily_rng := RandomNumberGenerator.new()
 daily_rng.seed = hash(Time.get_date_string_from_system() + audience)
 for i in range(pool.size() - 1, 0, -1):
  var j: int = daily_rng.randi_range(0, i)
  var temp: Variant = pool[i]
  pool[i] = pool[j]
  pool[j] = temp
 round_bank = pool.slice(0, 10)
 show_round()

func card_texture(card_name: String) -> Texture2D:
 var id: String = card_name.to_lower()
 var illustration: String = "res://assets/cards/" + id + ".png"
 if art_style == "illustration" and ResourceLoader.exists(illustration):
  return cached_texture(illustration)
 var photo: String = "res://assets/photos/" + id + ".jpg"
 if ResourceLoader.exists(photo):
  return cached_texture(photo)
 var generated: String = "res://assets/generated/" + id + ".webp"
 if ResourceLoader.exists(generated):
  return cached_texture(generated)
 return cached_texture(illustration)

func toggle_art_style() -> void:
 art_style = "illustration" if art_style == "realistic" else "realistic"
 save_progress()
 show_home()

func artwork_note(card_name: String) -> String:
 if art_style == "illustration" and ResourceLoader.exists("res://assets/cards/" + card_name.to_lower() + ".png"):
  return tr_ui("بطاقة مرسومة", "Illustrated card")
 if ResourceLoader.exists("res://assets/photos/" + card_name.to_lower() + ".jpg"):
  return tr_ui("صورة فوتوغرافية", "Photographic image")
 if ResourceLoader.exists("res://assets/generated/" + card_name.to_lower() + ".webp"):
  return tr_ui("صورة واقعية مولدة بالذكاء الاصطناعي", "AI-generated realistic image")
 return tr_ui("بطاقة مرسومة", "Illustrated card")

func record_picture_win() -> void:
 if picture_recorded:
  return
 picture_recorded = true
 profile["picture_wins"] = int(profile.get("picture_wins", 0)) + 1
 profile["wins"] = int(profile.get("wins", 0)) + 1
 LiveOps.update(profile, true)
 profile["matches"] = int(profile.get("matches", 0)) + 1
 var earned: int = maxi(10, 60 - turns * 4)
 profile["xp"] = int(profile.get("xp", 0)) + earned
 profile["best_0"] = maxi(int(profile.get("best_0", 0)), earned)
 save_progress()

const BG := Color("080f25")
const PANEL := Color("182a50")
const ACCENT := Color("7157e8")
const GREEN := Color("16b986")
const GOLD := Color("ffcf62")
const GAMES := ["Guess Your Picture", "Movie Masters", "Word Battle", "Brain Clash", "Mystery Quest", "Trivia Arena", "Sound Detective", "Who Am I?", "Picture Memory", "Step Builder"]
const ICONS := ["?", "M", "W", "B", "Q", "T", "S", "I"]
var CARD_NAMES_AR: Dictionary = {}
var PICTURE_QUESTIONS_AR: Array[String] = []

func card_display(name: String) -> String:
 for card in CARDS:
  if str(card["name"]) == name:
   return str(card[selected_language])
 return name

func translate_log(entry: String) -> String:
 if selected_language == "tr":
  return translate_turkish_log(entry)
 if selected_language != "ar":
  return entry
 var result: String = entry
 for q in range(QUESTIONS.size()):
  result = result.replace(str(QUESTIONS[q]["text"]), PICTURE_QUESTIONS_AR[q])
 result = result.replace("RIVAL GUESS:", "تخمين المنافس:").replace("YOU (auto):", "إجابتك التلقائية:")
 result = result.replace("YOU WIN!", "فزت!").replace("RIVAL WINS!", "فاز المنافس!").replace("DRAW!", "تعادل!")
 result = result.replace("YOU:", "أنت:").replace("RIVAL:", "المنافس:").replace("YES", "نعم").replace("NO", "لا")
 result = result.replace("A new match has started. Your card is hidden from you.", "بدأ تحدٍ جديد. استنتج بطاقتك من إجابات المنافس.")
 result = result.replace("Turn limit reached. Your card:", "انتهت الأدوار. بطاقتك:").replace("Your card:", "بطاقتك:").replace("Your card was", "كانت بطاقتك")
 result = result.replace("Wrong guess:", "تخمين غير صحيح:").replace("Type a guess first.", "اكتب تخمينك أولًا.").replace("Wrong AI guess. Keep playing!", "أخطأ المنافس. أكمل التحدي!")
 for card in CARDS:
  result = result.replace(str(card["name"]), card_display(str(card["name"])))
 return result

var game := -1
var question_index := 0
var score := 0
var ai_score := 0
var round_finished := false
var rng := RandomNumberGenerator.new()
var root: VBoxContainer
var status_label: Label
# Local offline opponent: the player never receives their own card in the UI.
var CARDS: Array = []
var QUESTIONS: Array = []

var my_secret: Dictionary = {}
var rival_secret: Dictionary = {}
var asked: Array[int] = []
var turns := 0
var rival_step := 0
var conversation: Array[String] = []
var picture_done := false
var rival_candidates: Array[Dictionary] = []
var picture_turn_limit := 10
var selected_language := "ar"
const GAME_NAMES_AR := ["خمن صورتك", "تحدي السينما", "ألغاز الكلمات", "معركة العقول", "مغامرة الألغاز", "ملك المعلومات", "خمن الصوت", "مين أنا؟", "ذاكرة الصور", "رتب الخطوات"]

func tr_ui(ar: String, en: String) -> String:
 return ar if selected_language == "ar" else (str(ui_tr.get(en, en)) if selected_language == "tr" else en)

func game_title(index: int) -> String:
 return tr_ui(GAME_NAMES_AR[index], GAMES[index])

func toggle_language() -> void:
 selected_language = ["ar", "en"][(["ar", "en"].find(selected_language) + 1) % 2]
 save_progress()
 show_home()

func _ready() -> void:
 if not DailyRounds.changed.is_connected(_on_daily_rounds_changed):
  DailyRounds.changed.connect(_on_daily_rounds_changed)
 if not AdManager.reward_earned.is_connected(_on_earned_ad_reward):
  AdManager.reward_earned.connect(_on_earned_ad_reward)
 rng.randomize()
 load_upgrade()
 _load_age_group()
 AdManager.set_audience("adults" if age_group == "18plus" else "children")
 if age_group == "unknown":
  show_age_group_selection()
 else:
  show_home()

func _load_age_group() -> void:
 age_group = "unknown"
 var age_path: String = "user://age_group_v1.json"
 if FileAccess.file_exists(age_path):
  var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(age_path))
  if parsed is Dictionary and str(parsed.get("group", "")) in ["under13", "13to17", "18plus"]:
   age_group = str(parsed["group"])

func _set_age_group(value: String) -> void:
 if value not in ["under13", "13to17", "18plus"]:
  return
 age_group = value
 var f := FileAccess.open("user://age_group_v1.json", FileAccess.WRITE)
 if f != null:
  f.store_string(JSON.stringify({"group": age_group}))
  f.close()
 AdManager.set_audience("adults" if age_group == "18plus" else "children")
 show_home()

func show_age_group_selection() -> void:
 clear_ui()
 label(tr_ui("اختر الفئة العمرية المناسبة", "CHOOSE YOUR AGE GROUP"), 29)
 label(tr_ui("اختيار الفئة يساعدنا نقدم تجربة مناسبة. لا نطلب تاريخ ميلادك.", "This helps us tailor the experience. We do not ask for your birthday."), 18)
 button(tr_ui("أقل من 13 سنة", "UNDER 13"), func(): _set_age_group("under13"), PANEL)
 button(tr_ui("من 13 إلى 17 سنة", "13–17 YEARS"), func(): _set_age_group("13to17"), PANEL)
 button(tr_ui("18 سنة أو أكثر", "18 OR OLDER"), func(): _set_age_group("18plus"), PANEL)
 button("العربية / English", show_languages, PANEL)

func _on_earned_ad_reward(kind: String, amount: int) -> void:
 # AdManager emits only after the real native earned-reward callback for a pending ID.
 if kind != "Coins" or amount != 50 or age_group != "18plus":
  return
 profile["coins"] = int(profile.get("coins", 0)) + amount
 save_progress()
 if is_inside_tree():
  show_ad_status()


func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_PAUSED:
  blitz_background_paused = true
  if is_instance_valid(blitz_timer):
   blitz_timer.paused = true
 elif what == NOTIFICATION_APPLICATION_RESUMED:
  blitz_background_paused = false
  if is_instance_valid(blitz_timer) and active_play_screen and not blitz_dialog_paused:
   blitz_timer.paused = false

func _process(_delta: float) -> void:
 if not active_play_screen or round_finished or not is_instance_valid(blitz_timer):
  return
 var remaining: float = blitz_timer.time_left
 if is_instance_valid(blitz_meter):
  blitz_meter.value = remaining
  blitz_meter.modulate = Color("ff9478") if remaining <= 6.0 else Color.WHITE
 if is_instance_valid(blitz_counter):
  blitz_counter.text = tr_ui("⏱ متبقي %d ثانية", "⏱ %d SECONDS LEFT") % ceili(remaining)

func clear_ui() -> void:
 active_play_screen = false
 if is_instance_valid(blitz_timer):
  blitz_timer.stop()
 blitz_dialog_paused = false
 blitz_timer = null
 blitz_meter = null
 blitz_counter = null
 memory_generation += 1
 stop_audio()
 for child in get_children():
  remove_child(child)
  child.queue_free()
 var background := VisualSkin.new()
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(background)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.offset_left = 16
 scroll.offset_top = 36
 scroll.offset_right = -16
 scroll.offset_bottom = -36
 # Allow a finger swipe to scroll without accidentally pressing a quiz answer.
 scroll.scroll_deadzone = 22
 scroll.follow_focus = true
 add_child(scroll)
 root = VBoxContainer.new()
 root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 root.add_theme_constant_override("separation", 17)
 var margins := MarginContainer.new()
 margins.add_theme_constant_override("margin_left", 5)
 margins.add_theme_constant_override("margin_right", 5)
 margins.add_theme_constant_override("margin_bottom", 24)
 margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(margins)
 margins.add_child(root)
 if reduced_motion:
  root.modulate.a = 1.0
 else:
  root.modulate.a = 0.0
  root.create_tween().tween_property(root, "modulate:a", 1.0, 0.18)

func label(text_value: String, font_size: int = 23) -> Label:
 var l := Label.new()
 l.text = text_value
 l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 l.add_theme_font_size_override("font_size", int(font_size * reading_scale))
 l.add_theme_color_override("font_color", Color.WHITE)
 root.add_child(l)
 return l

func button(text_value: String, action: Callable, color: Color = PANEL) -> Button:
 var b := Button.new()
 b.text = text_value
 b.custom_minimum_size = Vector2(0, 80 if reading_scale >= 1.25 or audience == "children" else 66)
 b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 b.add_theme_font_size_override("font_size", int(19 * reading_scale))
 b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var style := StyleBoxFlat.new()
 style.bg_color = color
 style.border_color = color.lightened(0.32)
 style.set_border_width_all(1)
 style.shadow_color = Color(0, 0, 0, 0.40)
 style.shadow_size = 12
 style.set_corner_radius_all(20)
 style.content_margin_left = 12
 style.content_margin_right = 12
 b.add_theme_stylebox_override("normal", style)
 b.add_theme_stylebox_override("hover", panel_style(color.lightened(0.12)))
 b.add_theme_stylebox_override("pressed", panel_style(color.darkened(0.12)))
 b.add_theme_stylebox_override("focus", panel_style(ACCENT.darkened(0.15)))
 var tone: String = "gold" if color == GOLD else ("teal" if color == GREEN else ("violet" if color == ACCENT else "secondary"))
 VisualSkin.decorate_button(b, tone)
 # Consistent touch targets and immediate tactile feedback for all game modes.
 b.focus_mode = Control.FOCUS_ALL
 b.add_theme_color_override("font_hover_color", Color("ffffff"))
 b.add_theme_color_override("font_pressed_color", Color("ffffff"))
 b.mouse_entered.connect(func() -> void:
  if not b.disabled:
   animate_touch_button(b, Vector2(1.015, 1.015), 0.10)
 )
 b.mouse_exited.connect(func() -> void:
  animate_touch_button(b, Vector2.ONE, 0.10)
 )
 b.button_down.connect(func() -> void:
  if not b.disabled:
   animate_touch_button(b, Vector2(0.985, 0.985), 0.07)
 )
 b.button_up.connect(func() -> void:
  animate_touch_button(b, Vector2.ONE, 0.10)
 )
 b.pressed.connect(func() -> void:
  if haptics_enabled and OS.get_name() == "Android":
   Input.vibrate_handheld(14)
  if sound_enabled:
   play_tap()
 )
 b.pressed.connect(action)
 root.add_child(b)
 return b

# Kill a previous animation before starting another: rapid taps cannot queue
# overlapping tweens that keep changing button scale after the touch ends.
func animate_touch_button(target: Button, desired_scale: Vector2, seconds: float) -> void:
 if not is_instance_valid(target):
  return
 var old: Variant = target.get_meta("touch_tween", null)
 if old is Tween:
  var previous: Tween = old as Tween
  if previous.is_valid():
   previous.kill()
 if reduced_motion:
  target.scale = Vector2.ONE
  return
 target.pivot_offset = target.size * 0.5
 var animation: Tween = target.create_tween()
 animation.tween_property(target, "scale", desired_scale, seconds)
 target.set_meta("touch_tween", animation)

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
   get_viewport().set_input_as_handled()
   if active_play_screen:
    confirm_leave_active_game()
   elif game != -1:
    show_home()
   else:
    confirm_quit_game()

func confirm_leave_active_game() -> void:
 if is_instance_valid(blitz_timer):
  blitz_dialog_paused = true
  blitz_timer.paused = true
 var dialog := ConfirmationDialog.new()
 dialog.title = tr_ui("إنهاء الجولة؟", "LEAVE THIS ROUND?")
 dialog.dialog_text = tr_ui("التقدم غير المحفوظ في الجولة الحالية سيضيع.", "Unsaved progress in this round will be lost.")
 dialog.ok_button_text = tr_ui("إنهاء الجولة", "LEAVE ROUND")
 dialog.cancel_button_text = tr_ui("متابعة اللعب", "KEEP PLAYING")
 add_child(dialog)
 dialog.confirmed.connect(show_home)
 dialog.popup_centered(Vector2i(360, 180))
 dialog.visibility_changed.connect(func() -> void:
  if not dialog.visible:
   blitz_dialog_paused = false
   if is_instance_valid(blitz_timer) and active_play_screen:
    blitz_timer.paused = blitz_background_paused
   dialog.queue_free()
 )

func confirm_quit_game() -> void:
 var dialog := ConfirmationDialog.new()
 dialog.title = tr_ui("الخروج من اللعبة؟", "EXIT GAME?")
 dialog.dialog_text = tr_ui("يمكنك العودة واللعب في أي وقت.", "You can return and play any time.")
 dialog.ok_button_text = tr_ui("خروج", "EXIT")
 dialog.cancel_button_text = tr_ui("إلغاء", "CANCEL")
 add_child(dialog)
 dialog.confirmed.connect(func(): get_tree().quit())
 dialog.popup_centered(Vector2i(360, 180))
 dialog.visibility_changed.connect(func() -> void:
  if not dialog.visible:
   dialog.queue_free()
 )

var daily_ai_screen_active: bool = false

func _daily_ai_claims() -> Dictionary:
 var path := "user://ai_daily_claims.json"
 if not FileAccess.file_exists(path):
  return {}
 var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
 return loaded if loaded is Dictionary else {}

func show_ai_daily() -> void:
 daily_ai_screen_active = true
 if not DailyAI.changed.is_connected(_on_daily_ai_changed):
  DailyAI.changed.connect(_on_daily_ai_changed)
 clear_ui()
 label(tr_ui("🖼️ خمن الصورة • تحديات اليوم", "🖼️ DAILY PICTURE CHALLENGES"), 30)
 label(tr_ui("6 صور جديدة كل يوم • المجموع المحفوظ: %d", "6 NEW DAILY IMAGES • TOTAL ARCHIVED: %d") % [DailyAI.total_pictures()], 17)
 button(tr_ui("🔄 إضافة صور الأيام الجديدة", "🔄 ADD NEW DAILY PICTURES"), func(): DailyAI.refresh(), PANEL)
 button(tr_ui("📚 تحميل 7 أيام أقدم", "📚 LOAD 7 OLDER DAYS"), func(): DailyAI.load_older(), PANEL)
 if DailyAI.item.is_empty():
  label(tr_ui("مفيش ألغاز صور متاحة حاليًا. الألعاب العادية شغالة بدون إنترنت.", "No picture riddles available right now. Offline games still work."), 19)
  if not DailyAI.last_error.is_empty():
   label(DailyAI.last_error, 14)
 else:
  label(tr_ui("لغز %d من %d", "PUZZLE %d OF %d") % [DailyAI.current_index + 1, DailyAI.pack.size()], 18)
  label(str(DailyAI.item.get("category_ar", "")) if selected_language == "ar" else str(DailyAI.item.get("category_en", "")), 23)
  if DailyAI.texture != null:
   var picture := TextureRect.new()
   picture.texture = DailyAI.texture
   picture.custom_minimum_size.y = 245
   picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
   root.add_child(picture)
   var pid: String = str(DailyAI.item.get("id", ""))
   var claims: Dictionary = _daily_ai_claims()
   if claims.has(pid):
    label(tr_ui("✅ تم لعب هذا اللغز سابقًا", "✅ PUZZLE ALREADY PLAYED"), 18)
    if bool(claims[pid]):
     label(tr_ui("أحسنت! إجابة صحيحة", "WELL DONE! CORRECT ANSWER"), 18)
    else:
     var answer_options: Array = DailyAI.item.get("choices_ar", []) if selected_language == "ar" else DailyAI.item.get("choices_en", [])
     var answer_index: int = int(DailyAI.item.get("correct_index", -1))
     if answer_index >= 0 and answer_index < answer_options.size():
      label(tr_ui("الإجابة الصحيحة: ", "CORRECT ANSWER: ") + str(answer_options[answer_index]), 18)
   else:
    var opts: Array = DailyAI.item.get("choices_ar", []) if selected_language == "ar" else DailyAI.item.get("choices_en", [])
    if opts.size() == 4:
     for i in range(opts.size()):
      var choice_idx: int = i
      button(str(opts[i]), func(): answer_ai_daily(choice_idx), GREEN)
  else:
   label(tr_ui("الصورة قيد التحميل", "Loading picture"), 17)
   if not DailyAI.last_error.is_empty():
    label(DailyAI.last_error, 14)
  button(tr_ui("⬅ السابق", "⬅ PREVIOUS"), func(): DailyAI.previous_puzzle(), PANEL)
  button(tr_ui("التالي ➡", "NEXT ➡"), func(): DailyAI.next_puzzle(), ACCENT)
 button(tr_ui("🏠 الرئيسية", "🏠 HOME"), show_home, ACCENT)

func _on_daily_ai_changed() -> void:
 if is_inside_tree() and daily_ai_screen_active:
  show_ai_daily()

func answer_ai_daily(index: int) -> void:
 if DailyAI.item.is_empty() or DailyAI.texture == null:
  return
 var pid: String = str(DailyAI.item.get("id", ""))
 if pid.is_empty():
  return
 var path := "user://ai_daily_claims.json"
 var claims: Dictionary = _daily_ai_claims()
 if claims.has(pid):
  return
 var correct: bool = index == int(DailyAI.item.get("correct_index", -1))
 claims[pid] = correct
 var file := FileAccess.open(path, FileAccess.WRITE)
 if file == null:
  return
 file.store_string(JSON.stringify(claims))
 file.close()
 if correct:
  profile["xp"] = int(profile.get("xp", 0)) + clampi(int(DailyAI.item.get("xp", 25)), 0, 50)
  save_progress()
 show_ai_daily()

func feature_card(title_text: String, description: String, action_text: String, action: Callable, tone: Color = ACCENT) -> void:
 var card := PanelContainer.new()
 card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var skin := StyleBoxFlat.new()
 skin.bg_color = Color("122347")
 skin.border_color = tone.lightened(0.15)
 skin.set_border_width_all(2)
 skin.set_corner_radius_all(22)
 skin.content_margin_left = 18
 skin.content_margin_right = 18
 skin.content_margin_top = 18
 skin.content_margin_bottom = 18
 skin.shadow_color = Color(0, 0, 0, 0.3)
 skin.shadow_size = 10
 card.add_theme_stylebox_override("panel", skin)
 root.add_child(card)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 10)
 card.add_child(column)
 var heading := Label.new()
 heading.text = title_text
 heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 heading.add_theme_font_size_override("font_size", int(24 * reading_scale))
 heading.add_theme_color_override("font_color", GOLD)
 column.add_child(heading)
 var details := Label.new()
 details.text = description
 details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 details.add_theme_font_size_override("font_size", int(16 * reading_scale))
 details.add_theme_color_override("font_color", Color("bcd3f7"))
 column.add_child(details)
 var play := button(action_text, action, tone)
 root.remove_child(play)
 column.add_child(play)

func make_game_tile(index: int, art_id: String, favorite: bool) -> PanelContainer:
 var tile := PanelContainer.new()
 tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var skin := StyleBoxFlat.new()
 skin.bg_color = Color("142447")
 skin.border_color = Color("3a5893")
 skin.set_border_width_all(2)
 skin.set_corner_radius_all(20)
 skin.content_margin_left = 8
 skin.content_margin_right = 8
 skin.content_margin_top = 8
 skin.content_margin_bottom = 10
 skin.shadow_color = Color(0, 0, 0, 0.34)
 skin.shadow_size = 8
 tile.add_theme_stylebox_override("panel", skin)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 6)
 tile.add_child(column)
 var art := TextureRect.new()
 art.texture = card_texture(art_id)
 art.custom_minimum_size.y = 150
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
 column.add_child(art)
 var idx: int = index
 var b := button(("★ " if favorite else "") + game_title(index) + "\n" + game_subtitle(index), func(): show_modes(idx), ACCENT if index % 3 == 0 else PANEL)
 root.remove_child(b)
 column.add_child(b)
 b.icon = cached_texture("res://assets/ui/game_%d.svg" % index)
 b.expand_icon = true
 b.add_theme_constant_override("icon_max_width", 28)
 return tile

# World journey: a persistent stage map with themed chapters and replayable challenges.
const JOURNEY_WORLDS: Array[String] = ["island", "city", "space", "mystery", "arena", "jungle", "ocean", "desert", "clouds", "volcano", "crystals", "robots", "temple", "ice", "stars"]
const JOURNEY_STAGE_COUNT: int = 180

func journey_world_name(index: int) -> String:
 var names_ar: Array[String] = ["🏝 جزيرة المغامرات", "🌆 مدينة الألغاز", "🚀 رحلة الفضاء", "🏰 مملكة الأسرار", "🏆 ساحة الأبطال", "🌿 غابة الاكتشاف", "🌊 أعماق المحيط", "🏜 صحراء الأسرار", "☁️ مدينة السحاب", "🌋 جزيرة البراكين", "💎 كهوف البلورات", "🤖 عالم الروبوتات", "🗿 المعبد القديم", "❄️ مملكة الجليد", "🌠 درب النجوم"]
 var names_en: Array[String] = ["🏝 ADVENTURE ISLAND", "🌆 PUZZLE CITY", "🚀 SPACE VOYAGE", "🏰 MYSTERY KINGDOM", "🏆 CHAMPIONS ARENA", "🌿 DISCOVERY JUNGLE", "🌊 DEEP OCEAN", "🏜 SECRET DESERT", "☁️ CLOUD CITY", "🌋 VOLCANO ISLAND", "💎 CRYSTAL CAVES", "🤖 ROBOT WORLD", "🗿 ANCIENT TEMPLE", "❄️ ICE KINGDOM", "🌠 STAR TRAIL"]
 return tr_ui(names_ar[index], names_en[index])

# Visual, touch-friendly world cards and compact stage grid (3 columns).
func journey_stage_tile(stage: int, unlocked: int) -> Button:
 var tile := Button.new()
 tile.custom_minimum_size = Vector2(0, 84)
 tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 tile.add_theme_font_size_override("font_size", 18)
 tile.text = ("★\n%d" % stage) if stage < unlocked else (("▶\n%d" % stage) if stage == unlocked else ("🔒\n%d" % stage))
 var accessible: bool = stage <= unlocked
 tile.disabled = not accessible
 var world_index: int = (stage - 1) / 12
 var colors: Array[Color] = [Color("0d6f80"), Color("5441a6"), Color("174b94"), Color("85466c"), Color("99601f")]
 var bg: Color = colors[world_index % colors.size()] if accessible else Color("242c3f")
 var skin := panel_style(bg)
 skin.set_corner_radius_all(15)
 tile.add_theme_stylebox_override("normal", skin)
 tile.add_theme_stylebox_override("disabled", panel_style(Color("242c3f")))
 tile.add_theme_stylebox_override("hover", panel_style(bg.lightened(0.16)))
 tile.add_theme_stylebox_override("pressed", panel_style(bg.darkened(0.12)))
 tile.add_theme_color_override("font_disabled_color", Color("8490a5"))
 if accessible:
  var chosen: int = stage
  tile.pressed.connect(func(): launch_journey_stage(chosen))
 return tile

func show_journey_map() -> void:
 clear_ui()
 label(tr_ui("🗺 رحلة الأبطال", "🗺 HEROES' JOURNEY"), 31)
 visual_banner("res://assets/ui/fantasy_world_art.png", 235)
 var unlocked: int = clampi(1 + int(profile.get("challenge_stage", 0)), 1, JOURNEY_STAGE_COUNT)
 label(tr_ui("%d / %d مرحلة مفتوحة", "%d / %d STAGES UNLOCKED") % [unlocked, JOURNEY_STAGE_COUNT], 20)
 var progress := ProgressBar.new()
 progress.min_value = 0
 progress.max_value = JOURNEY_STAGE_COUNT
 progress.value = unlocked
 progress.custom_minimum_size.y = 18
 progress.show_percentage = false
 root.add_child(progress)
 for world_index in range(JOURNEY_WORLDS.size()):
  var first: int = world_index * 12 + 1
  var last: int = first + 11
  world_art_card(world_index, journey_world_name(world_index), tr_ui("%d / 12 مرحلة", "%d / 12 STAGES") % clampi(unlocked - first + 1, 0, 12))
  var world_box := PanelContainer.new()
  world_box.add_theme_stylebox_override("panel", panel_style([Color("123f53"), Color("312c65"), Color("163b68"), Color("52304f"), Color("664021")][world_index % 5]))
  root.add_child(world_box)
  var inner := VBoxContainer.new()
  inner.add_theme_constant_override("separation", 10)
  world_box.add_child(inner)
  var heading := Label.new()
  heading.text = journey_world_name(world_index)
  heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  heading.add_theme_font_size_override("font_size", 24)
  inner.add_child(heading)
  var subtitle := Label.new()
  subtitle.text = tr_ui("%d / 12 مرحلة", "%d / 12 STAGES") % clampi(unlocked - first + 1, 0, 12)
  subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  inner.add_child(subtitle)
  var grid := GridContainer.new()
  grid.columns = 3
  grid.add_theme_constant_override("h_separation", 8)
  grid.add_theme_constant_override("v_separation", 8)
  inner.add_child(grid)
  for stage in range(first, last + 1):
   grid.add_child(journey_stage_tile(stage, unlocked))
 button(tr_ui("العودة للرئيسية", "BACK TO HOME"), show_home, ACCENT)

func launch_journey_stage(stage: int) -> void:
 if stage < 1 or stage > JOURNEY_STAGE_COUNT or stage > 1 + int(profile.get("challenge_stage", 0)):
  return
 # Stage choice is explicit; stage progression remains tied to completed challenges.
 profile["journey_selected_stage"] = stage
 difficulty = mini(3, 1 + (stage - 1) / 12)
 session_length = clampi(20 + (stage - 1) / 6 * 5, 20, 60)
 game = [3, 5, 1, 6, 7][(stage - 1) % 5]
 selected_topic = "all"
 save_progress()
 start_game()


# Expedition is an interactive, non-quiz adventure. Persistent best outcome and wins.
# Player decisions affect supplies and the final outcome; no server or paid assets required.
var expedition_room: int = 0
var expedition_energy: int = 5
var expedition_keys: int = 0
var expedition_route: String = ""
var expedition_log: Array[String] = []

func start_expedition() -> void:
 expedition_room = 0
 expedition_energy = 5
 expedition_keys = 0
 expedition_route = ""
 expedition_log.clear()
 show_expedition()

func expedition_choose(route: String) -> void:
 expedition_route = route
 expedition_room = 1
 if route == "cave":
  expedition_energy -= 1
  expedition_keys += 1
  expedition_log.append(tr_ui("دخلت الكهف وعثرت على مفتاح", "Entered the cave and found a key"))
 elif route == "forest":
  expedition_energy += 1
  expedition_log.append(tr_ui("جمعت طاقة إضافية من الغابة", "Recovered energy in the forest"))
 else:
  expedition_energy -= 2
  expedition_keys += 2
  expedition_log.append(tr_ui("عبرت الجسر وجمعت مفتاحين", "Crossed the bridge and collected two keys"))
 show_expedition()

func expedition_puzzle(choice: int) -> void:
 if choice == 2:
  expedition_keys += 1
  expedition_log.append(tr_ui("حللت شفرة البوابة وحصلت على مفتاح", "Solved the gate code and earned a key"))
 else:
  expedition_energy -= 2
  expedition_log.append(tr_ui("محاولة خاطئة: فقدت طاقتين", "Wrong code: lost two energy"))
 expedition_room = 2
 show_expedition()

func expedition_prepare(choice: String) -> void:
 if choice == "rest":
  expedition_energy += 2
  expedition_log.append(tr_ui("استعدت طاقتين قبل المواجهة", "Rested and restored two energy"))
 else:
  expedition_keys += 1
  expedition_energy -= 1
  expedition_log.append(tr_ui("بحثت عن مفتاح إضافي مقابل طاقة", "Searched for an extra key at an energy cost"))
 expedition_room = 3
 show_expedition()

func expedition_finish(choice: String) -> void:
 var won: bool = expedition_energy > 0 and ((choice == "unlock" and expedition_keys >= 2) or (choice == "force" and expedition_energy >= 5))
 if choice == "force":
  expedition_energy -= 3
 if won:
  profile["expedition_wins"] = int(profile.get("expedition_wins", 0)) + 1
  var reward: int = maxi(10, 25 + expedition_energy * 5 + expedition_keys * 10)
  profile["xp"] = int(profile.get("xp", 0)) + reward
  profile["expedition_best_reward"] = maxi(int(profile.get("expedition_best_reward", 0)), reward)
  expedition_log.append(tr_ui("فتحت غرفة الكنز! +%d خبرة", "Treasure chamber opened! +%d XP") % reward)
 else:
  expedition_log.append(tr_ui("انتهت المحاولة. جرّب مسارًا مختلفًا.", "Expedition failed. Try another route."))
 expedition_room = 4
 save_progress()
 show_expedition()

func show_expedition() -> void:
 clear_ui()
 label(tr_ui("🧭 رحلة المعبد المفقود", "🧭 THE LOST TEMPLE"), 30)
 label(tr_ui("مغامرة قرارات وموارد وألغاز — ليست أسئلة اختيار تقليدية", "An adventure of choices, resources and puzzles"), 17)
 label(tr_ui("⚡ طاقة: %d   🔑 مفاتيح: %d", "⚡ Energy: %d   🔑 Keys: %d") % [expedition_energy, expedition_keys], 21)
 var progress := ProgressBar.new()
 progress.max_value = 4
 progress.value = expedition_room
 progress.show_percentage = false
 root.add_child(progress)
 if expedition_room == 0:
  label(tr_ui("أمامك ثلاثة طرق. اختار طريقك بعناية؛ الموارد هتحدد قدرتك على فتح الكنز.", "Three paths lie ahead. Choose wisely; your resources decide the ending."), 23)
  button(tr_ui("🕳 الكهف — مفتاح، وطاقة أقل", "🕳 Cave — key, costs energy"), func(): expedition_choose("cave"), ACCENT)
  button(tr_ui("🌳 الغابة — استعادة الطاقة", "🌳 Forest — restore energy"), func(): expedition_choose("forest"), GREEN)
  button(tr_ui("🌉 الجسر — مفتاحان، مخاطرة أكبر", "🌉 Bridge — two keys, higher cost"), func(): expedition_choose("bridge"), GOLD)
 elif expedition_room == 1:
  label(tr_ui("🔐 بوابة الأرقام: 2، 4، 8، 16، ؟", "🔐 Number gate: 2, 4, 8, 16, ?"), 26)
  label(tr_ui("الإجابة الصحيحة تمنحك مفتاحًا. الخطأ يستهلك طاقتين.", "Correct answer earns a key; a mistake costs two energy."), 18)
  button("24", func(): expedition_puzzle(0))
  button("30", func(): expedition_puzzle(1))
  button("32", func(): expedition_puzzle(2), ACCENT)
 elif expedition_room == 2:
  label(tr_ui("⛺ قبل غرفة الكنز: ترتاح أم تبحث عن مفتاح آخر؟", "⛺ Before the treasure: rest or search for another key?"), 25)
  button(tr_ui("💚 استراحة: +2 طاقة", "💚 Rest: +2 energy"), func(): expedition_prepare("rest"), GREEN)
  button(tr_ui("🔎 بحث: +1 مفتاح، -1 طاقة", "🔎 Search: +1 key, -1 energy"), func(): expedition_prepare("search"), GOLD)
 elif expedition_room == 3:
  label(tr_ui("👑 حارس الكنز! افتح الباب بمفتاحين، أو حاول دفعه بقوة (تحتاج 5 طاقة).", "👑 Treasure guardian! Use two keys, or force the door with five energy."), 25)
  button(tr_ui("🔑 استخدم المفاتيح", "🔑 Use keys"), func(): expedition_finish("unlock"), GOLD)
  button(tr_ui("💪 افتح الباب بالقوة", "💪 Force the door"), func(): expedition_finish("force"), ACCENT)
 else:
  label(expedition_log[-1] if not expedition_log.is_empty() else "", 27)
  label(tr_ui("مرات الفوز: %d  •  أفضل مكافأة: %d XP", "Wins: %d  •  Best reward: %d XP") % [int(profile.get("expedition_wins", 0)), int(profile.get("expedition_best_reward", 0))], 20)
  button(tr_ui("🔁 مغامرة جديدة", "🔁 NEW EXPEDITION"), start_expedition, GREEN)
 if expedition_room < 4 and not expedition_log.is_empty():
  label(expedition_log[-1], 16)
 button(tr_ui("🏠 الرئيسية", "🏠 HOME"), show_home)

# Memory Vault: a real sequence-recall mini-game with escalating difficulty.
# No question-bank reuse. The sequence is regenerated each run.
var vault_level: int = 1
var vault_sequence: Array[int] = []
var vault_input: Array[int] = []
var vault_phase: String = ""
var vault_attempts: int = 0
const VAULT_SYMBOLS: Array[String] = ["🌙", "⭐", "💎", "🔥"]

func start_memory_vault() -> void:
 vault_level = 1
 vault_attempts = 0
 vault_new_round()

func vault_new_round() -> void:
 vault_sequence.clear()
 vault_input.clear()
 for i in range(2 + vault_level):
  vault_sequence.append(randi_range(0, VAULT_SYMBOLS.size() - 1))
 vault_phase = "study"
 show_memory_vault()

func vault_begin_recall() -> void:
 vault_phase = "recall"
 vault_input.clear()
 show_memory_vault()

func vault_choose(symbol: int) -> void:
 if vault_phase != "recall":
  return
 vault_input.append(symbol)
 var at: int = vault_input.size() - 1
 if vault_input[at] != vault_sequence[at]:
  vault_attempts += 1
  vault_phase = "failed"
 elif vault_input.size() == vault_sequence.size():
  vault_phase = "won"
  var xp_reward: int = 15 * vault_level
  profile["xp"] = int(profile.get("xp", 0)) + xp_reward
  profile["vault_rounds_won"] = int(profile.get("vault_rounds_won", 0)) + 1
  profile["vault_best_level"] = maxi(int(profile.get("vault_best_level", 0)), vault_level)
  save_progress()
 show_memory_vault()

func vault_next() -> void:
 if vault_phase != "won":
  return
 if vault_level >= 5:
  vault_phase = "complete"
  profile["vault_completions"] = int(profile.get("vault_completions", 0)) + 1
  save_progress()
  show_memory_vault()
 else:
  vault_level += 1
  vault_new_round()

func show_memory_vault() -> void:
 clear_ui()
 label(tr_ui("🧠 خزنة الذاكرة", "🧠 MEMORY VAULT"), 32)
 label(tr_ui("احفظ ترتيب الرموز ثم كرره بنفس التسلسل", "Memorize the symbols, then repeat their order"), 19)
 label(tr_ui("الجولة %d / 5   •   أخطاء المحاولة: %d", "Round %d / 5   •   Mistakes: %d") % [vault_level, vault_attempts], 20)
 var bar := ProgressBar.new()
 bar.max_value = 5
 bar.value = vault_level - 1
 bar.show_percentage = false
 root.add_child(bar)
 if vault_phase == "study":
  var symbols: String = ""
  for value in vault_sequence:
   symbols += VAULT_SYMBOLS[value] + "  "
  label(symbols, 33)
  button(tr_ui("جاهز! اخفِ الرموز", "READY! HIDE SYMBOLS"), vault_begin_recall, GREEN)
 elif vault_phase == "recall":
  label(tr_ui("تذكّر التسلسل: %d / %d", "Recall sequence: %d / %d") % [vault_input.size(), vault_sequence.size()], 23)
  var grid := GridContainer.new()
  grid.columns = 2
  root.add_child(grid)
  for i in range(VAULT_SYMBOLS.size()):
   var chosen: int = i
   var tile := Button.new()
   tile.text = VAULT_SYMBOLS[i]
   tile.custom_minimum_size = Vector2(145, 88)
   tile.add_theme_font_size_override("font_size", 34)
   tile.pressed.connect(func(): vault_choose(chosen))
   grid.add_child(tile)
 elif vault_phase == "failed":
  label(tr_ui("❌ ترتيب غير صحيح. حاول مجددًا بنفس المستوى.", "❌ Wrong order. Try this level again."), 24)
  button(tr_ui("🔁 إعادة المحاولة", "🔁 RETRY"), vault_new_round, ACCENT)
 elif vault_phase == "won":
  label(tr_ui("🏆 ممتاز! حصلت على %d XP", "🏆 Great! Earned %d XP") % (15 * vault_level), 25)
  button(tr_ui("الجولة التالية", "NEXT ROUND"), vault_next, GREEN)
 else:
  label(tr_ui("👑 فتحت خزنة الذاكرة! أنهيت الجولات الخمس.", "👑 Memory Vault unlocked! Five rounds complete."), 26)
  button(tr_ui("ابدأ تحديًا جديدًا", "PLAY AGAIN"), start_memory_vault, GREEN)
 label(tr_ui("أفضل جولة: %d  •  جولات فزت بها: %d", "Best round: %d  •  Rounds won: %d") % [int(profile.get("vault_best_level", 0)), int(profile.get("vault_rounds_won", 0))], 18)
 button(tr_ui("🏠 الرئيسية", "🏠 HOME"), show_home)

# Adventure Chain: linked, stateful stages (not a bank of quiz prompts).
var chain_stage: int = 0
var chain_hearts: int = 3
var chain_stars: int = 0
var chain_pattern: Array[int] = []
var chain_taps: Array[int] = []
var chain_phase: String = ""
var chain_finished: bool = false
var chain_code_start: int = 3
var chain_code_step: int = 3
var chain_code_answer: int = 21
var chain_code_options: Array[int] = []
var chain_code_attempts: int = 0
var chain_run_count: int = 0

func start_adventure_chain() -> void:
 chain_stage = 0
 chain_hearts = 3
 chain_stars = 0
 chain_finished = false
 chain_phase = "choose"
 chain_pattern.clear()
 chain_taps.clear()
 chain_code_attempts = 0
 chain_run_count += 1
 show_adventure_chain()

func chain_route(route: String) -> void:
 if chain_stage != 0 or chain_finished:
  return
 if route == "safe":
  chain_stars += 1
 else:
  chain_stars += 3
  chain_hearts -= 1
 chain_stage = 1
 chain_phase = "study"
 chain_pattern.clear()
 for i in range(3):
  chain_pattern.append(randi_range(0, 3))
 show_adventure_chain()

func chain_hide_pattern() -> void:
 if chain_stage != 1 or chain_phase != "study":
  return
 chain_phase = "recall"
 chain_taps.clear()
 show_adventure_chain()

func chain_tap(value: int) -> void:
 if chain_stage != 1 or chain_phase != "recall":
  return
 chain_taps.append(value)
 var idx: int = chain_taps.size() - 1
 if chain_taps[idx] != chain_pattern[idx]:
  chain_hearts -= 1
  chain_taps.clear()
  chain_phase = "study"
 elif chain_taps.size() == chain_pattern.size():
  chain_stars += 2
  chain_stage = 2
  chain_phase = "puzzle"
  chain_prepare_code()
 chain_check_lives()
 show_adventure_chain()

func chain_prepare_code() -> void:
 # A different arithmetic sequence every playthrough, with exactly one valid answer.
 chain_code_start = randi_range(2, 12)
 chain_code_step = randi_range(2, 6)
 chain_code_answer = chain_code_start + chain_code_step * 5 + 10
 chain_code_options = [chain_code_answer, chain_code_answer - chain_code_step - 3, chain_code_answer + chain_code_step + 2]
 chain_code_options.shuffle()
 chain_code_attempts = 0

func chain_answer(value: int) -> void:
 if chain_stage != 2 or chain_finished:
  return
 if value == chain_code_answer:
  chain_stars += 2
  chain_stage = 3
 else:
  chain_hearts -= 1
  chain_code_attempts += 1
  chain_check_lives()
 show_adventure_chain()

func chain_final(choice: String) -> void:
 if chain_stage != 3 or chain_finished:
  return
 if choice == "key" and chain_stars >= 4:
  chain_stars += 3
  chain_finished = true
 elif choice == "bridge" and chain_hearts >= 2:
  chain_stars += 1
  chain_finished = true
 else:
  chain_hearts -= 1
  chain_check_lives()
 if chain_finished and chain_hearts > 0:
  var reward: int = chain_stars * 10
  profile["xp"] = int(profile.get("xp", 0)) + reward
  profile["chain_wins"] = int(profile.get("chain_wins", 0)) + 1
  profile["chain_best_stars"] = maxi(int(profile.get("chain_best_stars", 0)), chain_stars)
  save_progress()
 show_adventure_chain()

func chain_check_lives() -> void:
 if chain_hearts <= 0:
  chain_hearts = 0
  chain_finished = true

func show_adventure_chain() -> void:
 clear_ui()
 label(tr_ui("🏝️ جزر المغامرة", "🏝️ ISLAND ADVENTURE"), 31)
 label(tr_ui("رحلة مترابطة: اختيار طريق ← ذاكرة ← شفرة ← بوابة", "One connected quest: route → memory → code → gate"), 17)
 label(tr_ui("❤️ %d قلوب    ⭐ %d نجوم", "❤️ %d hearts    ⭐ %d stars") % [chain_hearts, chain_stars], 23)
 var bar := ProgressBar.new()
 bar.max_value = 4
 bar.value = chain_stage
 bar.show_percentage = false
 root.add_child(bar)
 if chain_finished:
  if chain_hearts > 0:
   label(tr_ui("🏆 وصلت إلى جزيرة الكنز! +%d XP", "🏆 Treasure island reached! +%d XP") % (chain_stars * 10), 25)
  else:
   label(tr_ui("💔 نفدت القلوب. جرّب مسارًا آخر!", "💔 No hearts left. Try another route!"), 25)
  label(tr_ui("مرات الفوز: %d • أفضل نجوم: %d", "Wins: %d • Best stars: %d") % [int(profile.get("chain_wins", 0)), int(profile.get("chain_best_stars", 0))], 18)
  button(tr_ui("🔁 مغامرة جديدة", "🔁 PLAY AGAIN"), start_adventure_chain, GREEN)
 elif chain_stage == 0:
  label(tr_ui("🧭 طريقان إلى الجزيرة. تختار الأمان ولا المخاطرة؟", "🧭 Two routes: safe or risky?"), 24)
  button(tr_ui("🌳 الغابة الآمنة: +1 نجمة", "🌳 Safe forest: +1 star"), func(): chain_route("safe"), GREEN)
  button(tr_ui("🌋 البركان: +3 نجوم، -1 قلب", "🌋 Volcano: +3 stars, -1 heart"), func(): chain_route("risk"), GOLD)
 elif chain_stage == 1:
  label(tr_ui("🧠 احفظ الشفرة المكونة من 3 رموز", "🧠 Memorize the three-symbol code"), 23)
  if chain_phase == "study":
   var symbols: String = ""
   for v in chain_pattern:
    symbols += VAULT_SYMBOLS[v] + "  "
   label(symbols, 35)
   button(tr_ui("جاهز، اخفِ الرموز", "READY, HIDE SYMBOLS"), chain_hide_pattern, GREEN)
  else:
   label(tr_ui("اختر بالترتيب: %d / 3", "Repeat the sequence: %d / 3") % chain_taps.size(), 20)
   var grid := GridContainer.new()
   grid.columns = 2
   root.add_child(grid)
   for i in range(4):
    var picked: int = i
    var tile := Button.new()
    tile.text = VAULT_SYMBOLS[i]
    tile.custom_minimum_size = Vector2(140, 78)
    tile.pressed.connect(func(): chain_tap(picked))
    grid.add_child(tile)
 elif chain_stage == 2:
  var sequence: String = ""
  for n in range(5):
   if n > 0:
    sequence += "، "
   sequence += str(chain_code_start + chain_code_step * n + int(n * (n - 1) / 2))
  # Pattern grows by step, step+1, step+2, ...
  label(tr_ui("🔐 أكمل التسلسل: ", "🔐 Complete the sequence: ") + sequence + "، ؟", 24)
  label(tr_ui("الفروق بين الأرقام تتزايد بمقدار 1 كل مرة", "The gaps grow by 1 each time"), 17)
  if chain_code_attempts > 0:
   label(tr_ui("حاول مجددًا، القلوب المتبقية: %d", "Try again, hearts remaining: %d") % chain_hearts, 17)
  for option in chain_code_options:
   var picked: int = option
   button(str(picked), func(): chain_answer(picked), PANEL)
 elif chain_stage == 3:
  label(tr_ui("🚪 بوابة الكنز: 4 نجوم للمفتاح، أو قلبان لعبور الجسر", "🚪 Treasure gate: 4 stars for key, or 2 hearts for bridge"), 22)
  button(tr_ui("🔑 افتح بالمفتاح (4 نجوم)", "🔑 Unlock (4 stars)"), func(): chain_final("key"), GOLD)
  button(tr_ui("🌉 اعبر الجسر (قلبان)", "🌉 Cross bridge (2 hearts)"), func(): chain_final("bridge"), ACCENT)
 button(tr_ui("🏠 الرئيسية", "🏠 HOME"), show_home)

# v5.1: visual assets are concept illustrations integrated into real Godot UI,
# not screenshots or proof of fully implemented 3D gameplay.
func visual_banner(path: String, height: float = 205.0) -> void:
 if not ResourceLoader.exists(path):
  return
 var frame := PanelContainer.new()
 frame.add_theme_stylebox_override("panel", panel_style(Color("112746")))
 frame.custom_minimum_size.y = height
 frame.clip_contents = true
 root.add_child(frame)
 var art := TextureRect.new()
 art.texture = cached_texture(path)
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
 art.custom_minimum_size.y = height
 art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 frame.add_child(art)

func world_art_card(world_index: int, title_value: String, progress_value: String) -> void:
 var panel := PanelContainer.new()
 panel.add_theme_stylebox_override("panel", panel_style(Color("112a43")))
 root.add_child(panel)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 5)
 panel.add_child(stack)
 var art := TextureRect.new()
 art.texture = cached_texture("res://assets/ui/world_%d.webp" % (world_index % 5))
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
 art.custom_minimum_size.y = 120
 stack.add_child(art)
 var title_label := Label.new()
 title_label.text = title_value + "  ✦  " + progress_value
 title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 title_label.add_theme_font_size_override("font_size", 21)
 stack.add_child(title_label)

func show_home() -> void:
 if HomeLayoutCatalog.enabled():
  show_home_v2()
  return
 show_home_legacy()

func show_home_v2() -> void:
 if age_group == "unknown":
  show_age_group_selection()
  return
 daily_ai_screen_active = false
 game = -1
 clear_ui()
 VisualSkin.add_brand_banner(root, "res://assets/ui/gaming_hub_brand.png", tr_ui("✨ Gaming Hub • العب، اكتشف، واكسب", "✨ GAMING HUB • PLAY, DISCOVER, WIN"))
 xp_progress()
 stat_strip(tr_ui("مباريات", "MATCHES"), str(int(profile.get("matches", 0))), tr_ui("انتصارات", "WINS"), str(int(profile.get("wins", 0))))
 label(tr_ui("خمن صورتك", "GUESS YOUR PICTURE"), 30)
 if age_group != "under13":
  button(tr_ui("👥 العب مع صديق • غرفة وكود دعوة", "👥 PLAY WITH A FRIEND • ROOM CODE"), open_guess_multiplayer, GOLD)
  button(tr_ui("🌐 ابحث عن منافس أونلاين", "🌐 FIND AN ONLINE OPPONENT"), open_guess_multiplayer, ACCENT)
 button(tr_ui("🤖 العب ضد الكمبيوتر • بدون إنترنت", "🤖 PLAY VS COMPUTER • OFFLINE"), start_guess_offline, GREEN)
 button(tr_ui("🎮 قائمة الألعاب", "🎮 GAMES LIST"), show_games_list_v2, GOLD)
 label(tr_ui("الغرف والاتصال", "ROOMS & CONNECTION"), 23)
 if age_group != "under13":
  button(tr_ui("👥 إنشاء غرفة أو الانضمام بكود", "👥 CREATE OR JOIN ROOM"), open_guess_multiplayer, ACCENT)
 label(tr_ui("المحادثة والصوت متاحان داخل الغرف المدعومة فقط", "Chat and voice are available in supported rooms only"), 16)
 button(tr_ui("🔄 جلب تحديات جديدة", "🔄 FETCH NEW CHALLENGES"), func(): DailyRounds.refresh(true), PANEL)
 button("العربية / English", show_languages, PANEL)
 button(tr_ui("إعدادات اللعب والقراءة", "GAME & ACCESSIBILITY SETTINGS"), show_accessibility, PANEL)
 button(tr_ui("🛡 الخصوصية والإعلانات", "🛡 PRIVACY & ADS"), show_privacy_and_ads, PANEL)
 button(tr_ui("↩ الواجهة الأصلية", "↩ ORIGINAL HOME"), func(): HomeLayoutCatalog.set_enabled(false); show_home(), PANEL)

func show_games_list_v2() -> void:
 clear_ui()
 label(tr_ui("🎮 قائمة الألعاب", "🎮 GAMES LIST"), 30)
 label(tr_ui("كل الألعاب الحالية في مكان واحد", "ALL CURRENT GAMES IN ONE PLACE"), 17)
 var previews: Array[String] = ["tiger", "pyramids", "banana", "camera", "lighthouse", "eiffel", "violin", "dolphin", "penguin", "bicycle"]
 var favorites: Array = profile.get("favorites", [])
 var grid := GridContainer.new()
 grid.columns = 1 if reading_scale >= 1.25 or get_viewport_rect().size.x < 650 else 2
 root.add_child(grid)
 for i in range(GAMES.size()):
  grid.add_child(make_game_tile(i, previews[i % previews.size()], i in favorites))
 button(tr_ui("⚡ سباق السرعة ورحلة الكنز", "⚡ BLITZ & TREASURE"), func(): show_modes(5), GOLD)
 button(tr_ui("🎲 مفاجأة الجولة", "🎲 SURPRISE ME"), start_surprise_arcade, ACCENT)
 button(tr_ui("🏆 بطولة الأبطال", "🏆 CHAMPIONSHIP"), start_championship, GOLD)
 button(tr_ui("🖼️ تحديات الصور اليومية", "🖼️ DAILY PICTURE CHALLENGES"), show_ai_daily, GOLD)
 button(tr_ui("🧠 تحدي اليوم", "🧠 DAILY CHALLENGE"), start_daily, ACCENT)
 button(tr_ui("الإنجازات", "ACHIEVEMENTS"), show_achievements, PANEL)
 button(tr_ui("العودة للرئيسية", "BACK HOME"), show_home, GOLD)

func show_home_legacy() -> void:
 if age_group == "unknown":
  show_age_group_selection()
  return
 daily_ai_screen_active = false
 game = -1
 clear_ui()
 VisualSkin.add_brand_banner(root, "res://assets/ui/gaming_hub_brand.png", tr_ui("✨ Gaming Hub • العب، اكتشف، واكسب", "✨ GAMING HUB • PLAY, DISCOVER, WIN"))
 xp_progress()
 stat_strip(tr_ui("مباريات", "MATCHES"), str(int(profile.get("matches", 0))), tr_ui("انتصارات", "WINS"), str(int(profile.get("wins", 0))))
 label(tr_ui("اللعب الأساسي", "MAIN GAME"), 24)
 if age_group != "under13":
  button(tr_ui("👥 العب مع صديق • غرفة وكود دعوة", "👥 PLAY WITH A FRIEND • ROOM CODE"), open_guess_multiplayer, GOLD)
  button(tr_ui("🌐 ابحث عن منافس أونلاين", "🌐 FIND AN ONLINE OPPONENT"), open_guess_multiplayer, ACCENT)
 button(tr_ui("🤖 العب ضد الكمبيوتر • بدون إنترنت", "🤖 PLAY VS COMPUTER • OFFLINE"), start_guess_offline, GREEN)
 button(tr_ui("⚡ جولات جديدة: سباق السرعة ورحلة الكنز", "⚡ NEW ARCADE: BLITZ & TREASURE"), func(): show_modes(5), GOLD)
 button(tr_ui("🎲 مفاجأة الجولة • لعبة مختلفة كل مرة", "🎲 SURPRISE ME • A DIFFERENT GAME EACH TIME"), start_surprise_arcade, ACCENT)
 button(tr_ui("🏆 بطولة الأبطال • 3 مراحل وزعماء", "🏆 CHAMPIONSHIP • 3 STAGES & BOSSES"), start_championship, GOLD)
 if not DailyRounds.current_pack.is_empty():
  label(tr_ui("🌟 تحديات اليوم جديدة • محفوظ لديك %d سؤال إضافي", "🌟 TODAY'S CHALLENGES FIRST • %d STORED EXTRA QUESTIONS") % [DailyRounds.total_questions()], 17)
 else:
  label(tr_ui("🌐 تحديث الجولات اليومية قيد الانتظار • الألعاب الأساسية متاحة", "🌐 Daily refresh pending • built-in games available"), 16)
 button(tr_ui("🔄 جلب تحديات جديدة", "🔄 FETCH NEW CHALLENGES"), func(): DailyRounds.refresh(true), PANEL)
 button(tr_ui("📚 إضافة أسئلة أقدم للأرشيف", "📚 LOAD OLDER QUESTION PACKS"), func(): DailyRounds.load_older(), PANEL)
 button(tr_ui("🖼️ خمن الصورة • 6 ألغاز جديدة يوميًا", "🖼️ GUESS THE PICTURE • 6 NEW DAILY CHALLENGES"), show_ai_daily, GOLD)
 label(tr_ui("الأونلاين يحتاج سيرفر متصل. اللعب ضد الكمبيوتر متاح دون سيرفر.", "Online requires a connected server. AI/offline mode works without one."), 16)
 label(tr_ui("ألعاب إضافية", "MORE GAMES"), 23)
 button(tr_ui("🧩 اكتشف الألعاب الأخرى", "🧩 EXPLORE OTHER GAMES"), show_more_games, PANEL)
 button("العربية / English", show_languages, PANEL)
 button(tr_ui("إعدادات اللعب والقراءة", "GAME & ACCESSIBILITY SETTINGS"), show_accessibility, PANEL)
 button(tr_ui("🛡 الخصوصية والإعلانات", "🛡 PRIVACY & ADS"), show_privacy_and_ads, PANEL)

func start_championship() -> void:
 # No network, matchmaking, ads, or paid rewards. A deterministic 15-question local run.
 game = 5
 match_style = "championship"
 daily_match = false
 family_active = false
 campaign_active = false
 quick_match_active = false
 session_length = 15
 championship_stage = 1
 championship_stage_scores.clear()
 championship_total_errors = 0
 start_game()

func start_guess_offline() -> void:
 show_modes(0)

func start_surprise_arcade() -> void:
 # Only local/offline quiz titles are included; no fake matchmaking.
 var games: Array[int] = [1, 2, 3, 5, 6, 7, 9]
 var styles: Array[String] = ["blitz", "treasure", "chaos", "survival", "vault"]
 game = games[rng.randi_range(0, games.size() - 1)]
 match_style = styles[rng.randi_range(0, styles.size() - 1)]
 selected_topic = "all"
 daily_match = false
 family_active = false
 start_quick_match()

func show_more_games() -> void:
 clear_ui()
 label(tr_ui("ألعاب إضافية", "MORE GAMES"), 30)
 var grid := GridContainer.new()
 grid.columns = 1 if reading_scale >= 1.25 or get_viewport_rect().size.x < 650 else 2
 root.add_child(grid)
 var previews: Array[String] = ["tiger", "pyramids", "banana", "camera", "lighthouse", "eiffel", "violin", "dolphin", "penguin", "bicycle"]
 var favorites: Array = profile.get("favorites", [])
 for i in range(GAMES.size()):
  grid.add_child(make_game_tile(i, previews[i], i in favorites))
 button(tr_ui("🧠 تحدي اليوم", "🧠 DAILY CHALLENGE"), start_daily, ACCENT)
 button(tr_ui("الإنجازات", "ACHIEVEMENTS"), show_achievements)
 button(tr_ui("العودة للرئيسية", "BACK HOME"), show_home, GOLD)

func show_modes(index: int) -> void:
 if index != game:
  selected_topic = "all"
  quick_match_active = false
 game = index
 daily_match = false
 family_active = false
 campaign_active = false
 clear_ui()
 VisualSkin.add_hero(root, game_title(game), game_subtitle(game), tr_ui("اختر تحديك", "CHOOSE YOUR CHALLENGE"))
 if game not in [0, 4]:
  button(tr_ui("طول الجولة: %d • تعديل", "ROUND LENGTH: %d • CHANGE") % session_length, show_accessibility)
 button(tr_ui("★ أضف أو أزل من المفضلة", "★ TOGGLE FAVORITE"), toggle_favorite)
 if game in [0, 8]:
  button(tr_ui("البطاقات: ", "CARDS: ") + deck_title(), show_decks)
 if game > 0 and game != 8:
  label(tr_ui("أنشطة متاحة لملفك: %d", "ACTIVITIES FOR YOUR PROFILE: %d") % eligible_questions(game, false).size(), 16)
  if selected_topic != "all" and eligible_questions(game).size() < session_length:
   button(tr_ui("رحلة أطول بكل الموضوعات", "LONGER JOURNEY • ALL TOPICS"), func(): selected_topic = "all"; show_modes(game))
 if game > 0 and game != 8:
  button(tr_ui("الموضوع: ", "TOPIC: ") + topic_title(selected_topic), show_topics)
 if audience == "family" and game > 0 and game not in [4, 8]:
  button(tr_ui("لعب عائلي بالتناوب • على هذا الجهاز", "FAMILY TURN PLAY • on this device"), show_family_setup, GREEN)
 if game > 0 and game not in [4, 8]:
  label(tr_ui("أنماط منافسة جديدة", "NEW COMPETITIVE MODES"), 22)
  button(tr_ui("🏆 كلاسيكي", "🏆 CLASSIC"), func(): choose_match_style("classic"), GREEN if match_style == "classic" else PANEL)
  button(tr_ui("❤️ البقاء — 3 محاولات", "❤️ SURVIVAL — 3 LIVES"), func(): choose_match_style("survival"), GREEN if match_style == "survival" else PANEL)
  button(tr_ui("⚔ سباق النقاط ضد خصم محلي", "⚔ SCORE RACE — OFFLINE RIVAL"), func(): choose_match_style("rival"), GREEN if match_style == "rival" else PANEL)
  button(tr_ui("⚡ جولات المفاجآت", "⚡ SURPRISE ROUNDS"), func(): choose_match_style("chaos"), GREEN if match_style == "chaos" else PANEL)
  button(tr_ui("⏱ سباق السرعة • مؤقت ومكافأة للسرعة", "⏱ BLITZ • BEAT THE CLOCK"), func(): choose_match_style("blitz"), GOLD if match_style == "blitz" else PANEL)
  button(tr_ui("🎁 رحلة الكنز • اجمع المفاتيح واختر قوتك", "🎁 TREASURE TRAIL • EARN KEYS & CHOOSE BOOSTS"), func(): choose_match_style("treasure"), GOLD if match_style == "treasure" else PANEL)
  button(tr_ui("💎 خزنة الجرأة • احفظ أو خاطر بالنقاط", "💎 RISK VAULT • BANK OR RISK POINTS"), func(): choose_match_style("vault"), GOLD if match_style == "vault" else PANEL)
  if match_style == "blitz":
   label(tr_ui("34/27/21 ثانية حسب المستوى مع وقت إضافي للكتابة والترتيب. الإجابة السريعة تزيد نقاطك.", "34/27/21 SECONDS BY DIFFICULTY, PLUS EXTRA TIME FOR WRITING/ORDERING. FAST ANSWERS EARN MORE."), 16)
  elif match_style == "vault":
   label(tr_ui("كل إجابة صحيحة تزيد رصيد المخاطرة. كل 3 أسئلة احفظه أو ضاعفه بنسبة 50%. الخطأ يخسر غير المحفوظ فقط.", "CORRECT ANSWERS BUILD A RISK POT. EVERY THREE QUESTIONS BANK IT OR BOOST BY 50%. A MISTAKE LOSES ONLY UNBANKED POINTS."), 16)
  elif match_style == "treasure":
   label(tr_ui("الإجابة الصحيحة تمنحك مفتاحًا. عند كل 4 أسئلة تختار صندوقًا بمفتاحين.", "CORRECT ANSWERS GIVE KEYS. EVERY FOUR QUESTIONS, SPEND TWO KEYS FOR A CHEST."), 16)
 if game == 4:
  button(tr_ui("المغامرة: ", "ADVENTURE: ") + campaign_title(), show_campaigns, ACCENT)
  var checkpoint: Dictionary = profile.get("checkpoint_" + selected_campaign, {})
  var next_step: int = int(checkpoint.get("next", 0))
  label(tr_ui("مراحل مترابطة • يمكنك التوقف والعودة", "CONNECTED STAGES • PAUSE AND RETURN"), 19)
  button(tr_ui("تابع من المرحلة %d", "CONTINUE FROM STAGE %d") % (next_step + 1) if next_step > 0 and not bool(checkpoint.get("completed", false)) else tr_ui("ابدأ رحلة جديدة", "START A NEW JOURNEY"), start_game, GREEN)
 else:
  if game > 0 and game not in [4, 8]:
   button(tr_ui("🚀 مباراة سريعة • 10 أسئلة فقط", "🚀 QUICK MATCH • JUST 10 QUESTIONS"), start_quick_match, GREEN)
  label(tr_ui("اختر مستوى التحدي", "CHOOSE DIFFICULTY"), 21)
  label(match_style_name(), 19)
  for level in range(1, 4):
   var chosen: int = level
   button(difficulty_name(level), func(): difficulty = chosen; quick_match_active = false; start_game(), GREEN if level == 2 else PANEL)
 label(tr_ui("أفضل نتيجة: %d", "Personal best: %d") % int(profile.get("best_" + str(game), 0)), 17)
 if game == 0 and audience != "children":
  button(tr_ui("غرفة الأصدقاء • تجريبي", "FRIENDS ROOM • experimental"), func(): get_tree().change_scene_to_file("res://scenes/Multiplayer.tscn"), ACCENT)
 else:
  label(tr_ui("هذا الإصدار يدعم اللعب المحلي لهذه اللعبة", "This edition supports local play for this game"), 14)
 button(tr_ui("قائمة الألعاب", "Games menu"), show_home, ACCENT)

func show_unavailable(feature: String) -> void:
 clear_ui()
 label(feature, 26)
 label(tr_ui("غير متصل بعد. يحتاج هذا الوضع خادمًا واختبارًا بجهازين.", "Not connected yet. This mode needs a multiplayer backend and testing on two devices."), 19)
 button(tr_ui("العودة", "Back"), func(): show_modes(game), ACCENT)

func adaptive_level_for(game_index: int) -> int:
 var stats: Dictionary = profile.get("adaptive_stats", {})
 var key: String = str(game_index)
 var history: Array = stats.get(key, [])
 if history.size() < 6:
  return difficulty
 var recent: Array = history.slice(maxi(0, history.size() - 10))
 var successes: int = 0
 for value in recent:
  if bool(value):
   successes += 1
 var ratio: float = float(successes) / float(recent.size())
 if ratio >= 0.8:
  return mini(3, difficulty + 1)
 if ratio <= 0.35:
  return maxi(1, difficulty - 1)
 return difficulty

func record_adaptive_result(correct: bool) -> void:
 if family_active or campaign_active or daily_match:
  return
 var stats: Dictionary = profile.get("adaptive_stats", {})
 var key: String = str(game)
 var history: Array = stats.get(key, [])
 history.append(correct)
 if history.size() > 30:
  history = history.slice(history.size() - 30)
 stats[key] = history
 profile["adaptive_stats"] = stats

func adaptive_notice() -> String:
 var target: int = adaptive_level_for(game)
 if target > difficulty:
  return tr_ui("تحدٍ أعلى لأن أداءك اتحسن!", "Level up: you're ready for a harder challenge!")
 if target < difficulty:
  return tr_ui("جولة تدريبية لتقوية مستواك", "Practice round to build confidence")
 return ""

func match_style_name() -> String:
 match match_style:
  "survival":
   return tr_ui("البقاء: 3 محاولات", "SURVIVAL: THREE LIVES")
  "championship":
   return tr_ui("🏆 بطولة الأبطال", "🏆 CHAMPIONSHIP")
  "rival":
   return tr_ui("سباق النقاط ضد منافس محلي", "SCORE RACE: OFFLINE RIVAL")
  "chaos":
   return tr_ui("جولات المفاجآت", "SURPRISE ROUNDS")
  "blitz":
   return tr_ui("⏱ سباق السرعة", "⏱ BLITZ CHALLENGE")
  "treasure":
   return tr_ui("🎁 رحلة الكنز", "🎁 TREASURE TRAIL")
  "vault":
   return tr_ui("💎 خزنة الجرأة", "💎 RISK VAULT")
  _:
   return tr_ui("الجولة الكلاسيكية", "CLASSIC ROUND")

func choose_match_style(style: String) -> void:
 match_style = style
 show_modes(game)

func start_quick_match() -> void:
 # Quick play doesn't silently overwrite the player's preferred session length.
 quick_match_active = true
 var previous_length: int = session_length
 session_length = 10
 start_game()
 session_length = previous_length

func prepare_round_event() -> void:
 event_modifier = "normal"
 if match_style != "chaos":
  return
 var cycle: Array[String] = ["normal", "bonus", "no_hint", "comeback", "bonus"]
 event_modifier = cycle[question_index % cycle.size()]

func is_boss_round() -> bool:
 return not family_active and not campaign_active and not daily_match and question_index > 0 and (question_index + 1) % (5 if match_style == "championship" else 10) == 0

func challenge_tier() -> int:
 return mini(3, 1 + question_index / 10)

func event_description() -> String:
 match event_modifier:
  "bonus":
   return tr_ui("⚡ جولة مضاعفة: نقاط الإجابة الصحيحة ×2", "⚡ DOUBLE POINTS: correct answers ×2")
  "no_hint":
   return tr_ui("🔒 تحدي بلا تلميح", "🔒 NO-HINT CHALLENGE")
  "comeback":
   return tr_ui("🎯 فرصة العودة: +15 نقطة عند الإجابة الصحيحة", "🎯 COMEBACK: +15 for a correct answer")
  _:
   return tr_ui("جولة عادية", "STANDARD ROUND")

func update_offline_opponent() -> void:
 if match_style != "rival":
  return
 # Fixed seed from round index and difficulty: a reproducible, rule-based opponent.
 var roll: float = float((question_index * 37 + game * 19 + difficulty * 23 + 17) % 100) / 100.0
 if roll < opponent_skill:
  opponent_points += 10 * difficulty + 2 * (question_index % 3)

func arcade_variety_order(items: Array) -> Array:
 # One item per topic/mode in turn, keeping all IDs unique and the selection local.
 var queues: Dictionary = {}
 var topics: Array[String] = []
 for item in items:
  var category: String = str(item.get("topic", "mixed")) + ":" + str(item.get("mode", "choice"))
  if not queues.has(category):
   queues[category] = []
   topics.append(category)
  var bucket: Array = queues[category]
  bucket.append(item)
  queues[category] = bucket
 var result: Array = []
 while result.size() < items.size():
  var before: int = result.size()
  for category in topics:
   var pending: Array = queues[category]
   if not pending.is_empty():
    result.append(pending.pop_front())
    queues[category] = pending
  if result.size() == before:
   break
 return result

func start_game() -> void:
 selection_notice = false
 mixed_levels = false
 if game == 4:
  start_campaign()
  return
 campaign_active = false
 if game == 8:
  start_memory()
  return
 if game == 0:
  picture_turn_limit = 14 - difficulty * 2
  start_picture_game()
  return
 question_index = 0
 score = 0
 ai_score = 0
 lives_left = 5 if match_style == "championship" else 3
 opponent_points = 0
 opponent_skill = [0.45, 0.65, 0.82][clampi(difficulty - 1, 0, 2)]
 mode_finished_early = false
 match_reward_committed = false
 blitz_last_bonus = 0
 blitz_total_bonus = 0
 treasure_doubled_this_round = false
 treasure_keys = 0
 treasure_shields = 0
 treasure_doubles = 0
 treasure_claims = 0
 treasure_latest_checkpoint = -1
 treasure_saved_streak = false
 vault_pending = 0
 vault_banked = 0
 vault_decisions = 0
 vault_lost = 0
 vault_locked = false
 streak = 0
 correct_count = 0
 session_best_streak = 0
 session_mistakes = 0
 round_bank.clear()
 var eligible: Array = eligible_questions(game)
 var target_level: int = adaptive_level_for(game)
 for entry in eligible:
  if entry.has("campaign"):
   continue
  var item: Dictionary = entry.duplicate(true)
  if game == 4 or int(item.get("level", 1)) == target_level:
   round_bank.append(item)
 if round_bank.is_empty():
  selection_notice = not eligible.is_empty()
  round_bank = eligible.duplicate(true)
 if game != 4:
  if round_bank.size() < session_length:
   for distance in [1, 2]:
    for entry in eligible:
     if not entry.has("campaign") and absi(int(entry.get("level", 1)) - target_level) == distance:
      round_bank.append(entry.duplicate(true))
   mixed_levels = round_bank.size() > 0 and round_bank.any(func(q): return int(q.get("level", 1)) != target_level)
  shuffle_items(round_bank)
  var unique: Array = []
  var ids: Array = []
  for entry in round_bank:
   if entry["id"] not in ids:
    ids.append(entry["id"])
    unique.append(entry)
  round_bank = unique
  var recent: Array = profile.get("recent", [])
  var unseen: Array = []
  var seen: Array = []
  for entry in round_bank:
   if str(entry.get("id", "")) in recent:
    seen.append(entry)
   else:
    unseen.append(entry)
  round_bank = unseen + seen
  if mixed_levels:
   var preferred: Array = []
   var nearby: Array = []
   for entry in round_bank:
    if int(entry.get("level", 1)) == target_level:
     preferred.append(entry)
    else:
     nearby.append(entry)
   round_bank = preferred + nearby
  # Balance distinct topics/modes so a session doesn't feel like the same question repeated.
  var recent_ids: Array = profile.get("recent", [])
  var fresh_questions: Array = []
  var familiar_questions: Array = []
  for question in round_bank:
   if str(question.get("id", "")) in recent_ids:
    familiar_questions.append(question)
   else:
    fresh_questions.append(question)
  round_bank = arcade_variety_order(fresh_questions) + arcade_variety_order(familiar_questions)
  # Preserve the tenth-question boss cadence after applying topic variety.
  var ordered: Array = []
  var bosses: Array = []
  for candidate in round_bank:
   if int(candidate.get("level", 1)) >= 3:
    bosses.append(candidate)
   else:
    ordered.append(candidate)
  if not bosses.is_empty():
   var output: Array = []
   var all_regular: Array = ordered + bosses
   for slot in range(mini(session_length, all_regular.size())):
    if (slot + 1) % 10 == 0 and not bosses.is_empty():
     output.append(bosses.pop_front())
    elif not ordered.is_empty():
     output.append(ordered.pop_front())
    elif not bosses.is_empty():
     output.append(bosses.pop_front())
   round_bank = output
  else:
   round_bank = round_bank.slice(0, mini(session_length, round_bank.size()))

 # Show newly downloaded challenges at the top of normal rounds, not only in storage.
 # Keep boss and championship logic unchanged; cap the featured block to 3 items.
 if game in [2, 3, 5] and not daily_match and not campaign_active and not family_active:
  var today_prefix: String = "remote_" + Time.get_date_string_from_system(true) + "_"
  var recently_played: Array = profile.get("recent", [])
  var featured: Array = []
  var others: Array = []
  # Today's unplayed questions are selected from the full eligible pool before
  # trimming/shuffling, so at least three (when present) truly start the session.
  for entry in eligible:
   if str(entry.get("id", "")).begins_with(today_prefix) and str(entry.get("id", "")) not in recently_played and (selected_topic == "all" or str(entry.get("topic", "")) == selected_topic) and featured.size() < 3:
    featured.append(entry.duplicate(true))
  var featured_ids: Dictionary = {}
  for entry in featured:
   featured_ids[str(entry.get("id", ""))] = true
  for entry in round_bank:
   if not featured_ids.has(str(entry.get("id", ""))):
    others.append(entry)
  round_bank = (featured + others).slice(0, mini(session_length, featured.size() + others.size()))

 show_round()

func round_header_card() -> void:
 var frame := PanelContainer.new()
 frame.add_theme_stylebox_override("panel", panel_style(Color("15274d")))
 root.add_child(frame)
 var inner := VBoxContainer.new()
 inner.add_theme_constant_override("separation", 10)
 frame.add_child(inner)
 var title_line := Label.new()
 title_line.text = tr_ui("✦ تحدي المعرفة", "✦ KNOWLEDGE CHALLENGE")
 title_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title_line.add_theme_color_override("font_color", GOLD)
 title_line.add_theme_font_size_override("font_size", int(17 * reading_scale))
 inner.add_child(title_line)
 var status_line := Label.new()
 status_line.text = tr_ui("السؤال %d من %d   •   ⭐ %d نقطة", "QUESTION %d OF %d   •   ⭐ %d POINTS") % [question_index + 1, round_bank.size(), score]
 status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 status_line.add_theme_font_size_override("font_size", int(18 * reading_scale))
 inner.add_child(status_line)
 var meter := ProgressBar.new()
 meter.max_value = maxi(1, round_bank.size())
 meter.value = question_index + 1
 meter.show_percentage = false
 meter.custom_minimum_size.y = 13
 VisualSkin.decorate_progress(meter, true)
 inner.add_child(meter)
 if match_style == "survival" and not campaign_active and not daily_match and not family_active:
  var hearts := Label.new()
  hearts.text = tr_ui("المحاولات: ", "LIVES: ") + "♥ ".repeat(maxi(0, lives_left)) + "♡ ".repeat(maxi(0, 3 - lives_left))
  hearts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  hearts.add_theme_color_override("font_color", Color("ff849a"))
  inner.add_child(hearts)

func visual_challenge_type() -> int:
 # Alternate puzzle rules across questions instead of showing one identical picture task.
 return (question_index / 3) % 3

func round_picture_card(id: String) -> void:
 var frame := PanelContainer.new()
 var skin := panel_style(Color("0e1c38"))
 skin.border_color = Color("3b8dff")
 skin.set_border_width_all(2)
 skin.shadow_color = Color(0.05, 0.3, 0.9, 0.35)
 skin.shadow_size = 14
 frame.add_theme_stylebox_override("panel", skin)
 root.add_child(frame)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 8)
 frame.add_child(column)
 var challenge: int = visual_challenge_type()
 var columns: int = 4 if challenge == 0 else (5 if challenge == 1 else 3)
 var tile_total: int = columns * columns
 var reveal_step: int = 4 if challenge == 0 else (3 if challenge == 1 else 2)
 var names_ar: Array[String] = ["🧩 الصورة المفقودة", "🔍 تحقيق بصري", "⚡ تحدي النظرة السريعة"]
 var names_en: Array[String] = ["🧩 MISSING PICTURE", "🔍 VISUAL INVESTIGATION", "⚡ QUICK LOOK CHALLENGE"]
 var challenge_label := Label.new()
 challenge_label.text = names_ar[challenge] if selected_language == "ar" else names_en[challenge]
 challenge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 challenge_label.add_theme_color_override("font_color", GOLD)
 challenge_label.add_theme_font_size_override("font_size", 21)
 column.add_child(challenge_label)
 var picture_area := Control.new()
 picture_area.custom_minimum_size.y = 255
 picture_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 column.add_child(picture_area)
 var image := TextureRect.new()
 image.texture = card_texture(id)
 image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture_area.add_child(image)
 var cover := GridContainer.new()
 cover.columns = columns
 cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 cover.add_theme_constant_override("h_separation", 2)
 cover.add_theme_constant_override("v_separation", 2)
 picture_area.add_child(cover)
 var tiles: Array[ColorRect] = []
 for tile_index in range(tile_total):
  var tile := ColorRect.new()
  tile.color = Color("192d65") if (tile_index + tile_index / columns) % 2 == 0 else Color("244887")
  tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
  tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
  tile.custom_minimum_size = Vector2(24, 35)
  cover.add_child(tile)
  tiles.append(tile)
 var reveal_order: Array = range(tile_total)
 shuffle_items(reveal_order)
 var revealed := [0]
 # Quick-look rounds give the player a tiny starting glimpse without spending a hint.
 if challenge == 2:
  for initial in range(2):
   tiles[int(reveal_order[initial])].visible = false
   revealed[0] += 1
 var counter := Label.new()
 counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 counter.add_theme_font_size_override("font_size", 16)
 column.add_child(counter)
 var update_counter := func() -> void:
  counter.text = tr_ui("الأجزاء المكشوفة: %d / %d", "VISIBLE TILES: %d / %d") % [revealed[0], tile_total]
 update_counter.call()
 var reveal_button := Button.new()
 reveal_button.text = tr_ui("🔎 اكشف المزيد • مكافأة أقل", "🔎 REVEAL MORE • LOWER REWARD")
 reveal_button.custom_minimum_size.y = 54
 column.add_child(reveal_button)
 reveal_button.pressed.connect(func() -> void:
  if round_finished or revealed[0] >= tile_total:
   return
  hint_used = true
  for step in range(reveal_step):
   if revealed[0] >= reveal_order.size():
    break
   var tile_id: int = int(reveal_order[revealed[0]])
   tiles[tile_id].visible = false
   revealed[0] += 1
  update_counter.call()
  if revealed[0] >= tile_total:
   reveal_button.disabled = true
   reveal_button.text = tr_ui("الصورة مكشوفة بالكامل", "PICTURE FULLY REVEALED")
 )
 var note := Label.new()
 note.text = artwork_note(id)
 note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 note.add_theme_font_size_override("font_size", 12)
 note.add_theme_color_override("font_color", Color("a9c1e5"))
 column.add_child(note)

func round_choice_grid(item: Dictionary) -> void:
 var choices: Array = item["choices_" + selected_language]
 var order: Array = range(choices.size())
 shuffle_items(order)
 var grid := GridContainer.new()
 grid.columns = 1 # Portrait: full-width answers with readable text
 grid.add_theme_constant_override("h_separation", 10)
 grid.add_theme_constant_override("v_separation", 10)
 root.add_child(grid)
 for index in order:
  var chosen: int = int(index)
  var choice_button := button(str(choices[chosen]), func(): select_answer(chosen), Color("163867"))
  root.remove_child(choice_button)
  grid.add_child(choice_button)
  choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  choice_button.custom_minimum_size.y = 82
  choice_button.add_theme_color_override("font_color", Color("f5f9ff"))

func show_round() -> void:
 if family_active and not family_ready:
  show_family_handover()
  return
 if round_bank.is_empty() or question_index >= round_bank.size():
  show_modes(game)
  return
 prepare_round_event()
 round_finished = false
 answer_feedback = ""
 hint_used = false
 clue_index = 0
 clear_ui()
 active_play_screen = true
 label(tr_ui("تحدي اليوم", "DAILY CHALLENGE") if daily_match else (campaign_title() if campaign_active else game_title(game)), 29)
 if family_active:
  label(family_names[family_player] + tr_ui(" • دورك", " • YOUR TURN"), 23)
 round_header_card()
 if match_style == "blitz" and not campaign_active and not family_active and not daily_match:
  start_blitz_clock()
 if is_boss_round():
  label(tr_ui("👑 تحدي الزعيم • سؤال أصعب • مكافأة ×3", "👑 BOSS ROUND • HARDER CHALLENGE • TRIPLE REWARD"), 22)
 elif not family_active and not campaign_active and not daily_match and (question_index + 1) % 5 == 0:
  label(tr_ui("⚡ محطة التحدي • مكافأة مضاعفة", "⚡ CHECKPOINT • DOUBLE REWARD"), 20)
 if not family_active and not campaign_active and not daily_match:
  label(match_style_name(), 18)
  if match_style == "survival":
   label(tr_ui("المحاولات المتبقية: %d", "LIVES LEFT: %d") % lives_left, 19)
  elif match_style == "rival":
   label(tr_ui("أنت %d  •  المنافس المحلي %d", "YOU %d  •  OFFLINE RIVAL %d") % [score, opponent_points], 20)
  elif match_style == "chaos":
   label(event_description(), 19)
  elif match_style == "treasure":
   label(tr_ui("🗝 مفاتيح: %d  •  🛡 دروع: %d  •  ✨ مضاعف: %d", "🗝 KEYS: %d  •  🛡 SHIELDS: %d  •  ✨ BOOSTS: %d") % [treasure_keys, treasure_shields, treasure_doubles], 19)
  elif match_style == "vault":
   label(tr_ui("💎 محفوظ: %d  •  في المخاطرة: %d", "💎 BANKED: %d  •  AT RISK: %d") % [vault_banked, vault_pending], 19)
  elif match_style == "blitz":
   label(tr_ui("⏱ جاوب قبل انتهاء الوقت لتحصل على نقاط سرعة!", "⏱ ANSWER BEFORE THE CLOCK RUNS OUT FOR BONUS POINTS!"), 17)

 var progress := ProgressBar.new()
 progress.max_value = round_bank.size()
 progress.value = question_index
 progress.show_percentage = false
 progress.tooltip_text = tr_ui("تقدم الجولة: %d من %d", "Round progress: %d of %d") % [question_index, round_bank.size()]
 progress.custom_minimum_size.y = 12
 VisualSkin.decorate_progress(progress)
 root.add_child(progress)
 var item: Dictionary = round_bank[question_index]
 label(tr_ui("🧭 نوع التحدي: ", "🧭 CHALLENGE TYPE: ") + topic_title(str(item.get("topic", "all"))), 16)
 label(difficulty_name(int(item.get("level", 1))), 15)
 if question_index == 0 and not adaptive_notice().is_empty() and not campaign_active and not family_active:
  label(adaptive_notice(), 16)
 if question_index > 0 and not family_active:
  var answered: int = question_index
  var accuracy_so_far: int = roundi(100.0 * correct_count / answered)
  label(tr_ui("دقتك حتى الآن: %d%%  •  أفضل سلسلة: %d", "Accuracy so far: %d%%  •  Best streak: %d") % [accuracy_so_far, session_best_streak], 16)
 if mixed_levels:
  label(tr_ui("رحلة متنوعة: أضفنا مستويات قريبة لإطالة الجولة دون تكرار", "MIXED JOURNEY: NEARBY LEVELS ADDED WITHOUT REPEATING QUESTIONS"), 15)
 if selection_notice:
  label(tr_ui("لا توجد أسئلة لهذا المستوى في الموضوع؛ نعرض المتاح", "No questions at that level in this topic; showing available content"), 15)
 if campaign_active:
  if selected_campaign == "island":
   label(str(campaign_data["acts"][selected_language][int(item.get("act", 0))]), 22)
   label(tr_ui("قطع الخريطة: %d / 5", "MAP PIECES: %d / 5") % (question_index / 6), 16)
   campaign_scene(int(item.get("act", 0)), 105)
  if item.has("narrative_" + selected_language):
   label(str(item["narrative_" + selected_language]), 20)
 if game == 4 and not daily_match and selected_campaign == "archive":
  label(tr_ui("الفصل %d • أرشيف الأسرار", "Chapter %d • The Secret Archive") % (question_index + 1), 19)
 if item.has("image"):
  round_picture_card(str(item["image"]))
 VisualSkin.add_question_panel(root, str(item.get(selected_language, item.get("en", ""))), reading_scale, tr_ui("✦ السؤال ✦", "✦ THE CHALLENGE ✦"))
 if item.has("audio"):
  label(tr_ui("مقطع صوتي مُركّب • يمكنك إعادة الاستماع", "Synthesized clip • replay any time"), 15)
  button(tr_ui("▶ استمع للصوت", "▶ PLAY SOUND"), func(): play_clip(str(item["audio"])), GREEN)
 var mode: String = str(item.get("mode", "choice"))
 if mode == "order":
  show_order_choices(item)
 elif mode == "write" or mode == "identity":
  if mode == "identity":
   clue_label = label(str(item["clues_" + selected_language][0]), 21)
   clue_button = button(tr_ui("اكشف دليلًا آخر • نقاط أقل", "REVEAL NEXT CLUE • fewer points"), reveal_clue)
  var field := LineEdit.new()
  field.add_theme_font_size_override("font_size", int(21 * reading_scale))
  field.placeholder_text = tr_ui("اكتب إجابتك هنا", "Type your answer here")
  field.custom_minimum_size.y = 58
  root.add_child(field)
  var submit := func(): submit_written(field.text)
  field.text_submitted.connect(func(_value: String): submit.call())
  button(tr_ui("تحقق من الإجابة", "CHECK ANSWER"), submit, GREEN)
 else:
  round_choice_grid(item)
 if mode != "identity" and (event_modifier != "no_hint" or campaign_active or family_active or daily_match):
  hint_button = button(tr_ui("تلميح • نقاط أقل", "HINT • fewer points"), show_hint, ACCENT)
  hint_label = label("", 17)
 button(tr_ui("إنهاء الجولة والعودة", "EXIT MATCH"), confirm_leave_active_game)

func start_blitz_clock() -> void:
 blitz_duration = [34.0, 27.0, 21.0][clampi(difficulty - 1, 0, 2)]
 var active_item: Dictionary = round_bank[question_index]
 if str(active_item.get("mode", "choice")) in ["write", "identity", "order"]:
  blitz_duration += 12.0 # Fairer time limit for typing and multi-step puzzles.
 blitz_counter = label("", 22)
 blitz_counter.add_theme_color_override("font_color", GOLD)
 blitz_meter = ProgressBar.new()
 blitz_meter.max_value = blitz_duration
 blitz_meter.value = blitz_duration
 blitz_meter.show_percentage = false
 blitz_meter.custom_minimum_size.y = 13
 VisualSkin.decorate_progress(blitz_meter)
 root.add_child(blitz_meter)
 blitz_timer = Timer.new()
 blitz_timer.one_shot = true
 blitz_timer.wait_time = blitz_duration
 add_child(blitz_timer)
 blitz_timer.timeout.connect(blitz_timeout)
 blitz_timer.paused = blitz_background_paused
 blitz_timer.start()

func blitz_timeout() -> void:
 if round_finished or not active_play_screen or question_index >= round_bank.size():
  return
 answer_feedback = tr_ui("⏰ انتهى الوقت! تقدر تكمل التحدي التالي.", "⏰ TIME UP! YOU CAN KEEP GOING.")
 finish_round(false, correct_answer_text(round_bank[question_index]))

func correct_answer_text(item: Dictionary) -> String:
 var mode: String = str(item.get("mode", "choice"))
 if mode == "order":
  return " → ".join(PackedStringArray(item.get("steps_" + selected_language, [])))
 if mode == "write" or mode == "identity":
  var accepted: Array = item.get("answers_" + selected_language, [])
  return str(accepted[0]) if not accepted.is_empty() else ""
 var options: Array = item.get("choices_" + selected_language, [])
 var right: int = int(item.get("correct", 0))
 return str(options[right]) if right >= 0 and right < options.size() else ""

func show_treasure_checkpoint() -> void:
 clear_ui()
 label(tr_ui("🎁 وصلت لصندوق الكنز!", "🎁 TREASURE CHECKPOINT!"), 30)
 label(tr_ui("قطعت %d من %d جولات", "YOU FINISHED %d OF %d ROUNDS") % [question_index, round_bank.size()], 20)
 label(tr_ui("🗝 مفاتيحك: %d  •  التكلفة: مفتاحان", "🗝 YOUR KEYS: %d  •  COST: TWO KEYS") % treasure_keys, 21)
 if treasure_keys >= 2:
  label(tr_ui("اختار مكافأة واحدة للصندوق. المكافآت داخل اللعبة ومجانية.", "CHOOSE ONE IN-GAME BOOST. NO ADS OR PURCHASE REQUIRED."), 17)
  button(tr_ui("💰 +30 نقطة فورًا", "💰 +30 POINTS NOW"), func(): claim_treasure("points"), GOLD)
  button(tr_ui("✨ ضاعف نقاط إجابتك الصحيحة القادمة", "✨ DOUBLE YOUR NEXT CORRECT ANSWER"), func(): claim_treasure("double"), ACCENT)
  button(tr_ui("🛡 احمِ سلسلة الإجابات من خطأ واحد", "🛡 PROTECT YOUR STREAK FROM ONE MISTAKE"), func(): claim_treasure("shield"), GREEN)
 else:
  label(tr_ui("جاوب صح واجمع مفاتيح أكتر في الجولات القادمة!", "GET MORE ANSWERS RIGHT TO EARN KEYS!"), 18)
 button(tr_ui("متابعة من غير صندوق", "CONTINUE WITHOUT CHEST"), show_round)

func claim_treasure(reward: String) -> void:
 if match_style != "treasure" or treasure_keys < 2 or treasure_latest_checkpoint == question_index:
  return
 treasure_latest_checkpoint = question_index
 treasure_keys -= 2
 treasure_claims += 1
 match reward:
  "points":
   score += 30
  "double":
   treasure_doubles += 1
  "shield":
   treasure_shields += 1
 play_feedback("success")
 show_round()

func finish_round(correct: bool, answer: String) -> void:
 if round_finished:
  return
 round_finished = true
 var remaining_time: float = blitz_timer.time_left if is_instance_valid(blitz_timer) else 0.0
 if is_instance_valid(blitz_timer):
  blitz_timer.stop()
 blitz_last_bonus = 0
 treasure_saved_streak = false
 treasure_doubled_this_round = false
 stop_audio()
 var item: Dictionary = round_bank[question_index]
 var missed: Array = profile.get("missed", [])
 var item_id: String = str(item.get("id", ""))
 if correct:
  missed.erase(item_id)
 elif not item_id.is_empty() and item_id not in missed:
  missed.append(item_id)
 profile["missed"] = missed
 record_adaptive_result(correct)
 var recent: Array = profile.get("recent", [])
 recent.erase(item_id)
 recent.append(item_id)
 profile["recent"] = recent.slice(maxi(0, recent.size() - 80))
 var earned: int = 0
 if correct:
  streak += 1
  session_best_streak = maxi(session_best_streak, streak)
  correct_count += 1
  earned = maxi(5, 10 * int(item.get("level", 1)) + mini(streak - 1, 5) * 2 - (5 if hint_used else 0) - clue_index * 4)
  if family_active:
   earned = maxi(5, 10 - (5 if hint_used else 0) - clue_index * 2)
   family_scores[family_player] += earned
  if match_style == "chaos" and not campaign_active and not family_active and not daily_match:
   if event_modifier == "bonus":
    earned *= 2
   elif event_modifier == "comeback":
    earned += 15
  if is_boss_round():
   earned *= 3
  elif not family_active and not campaign_active and not daily_match and (question_index + 1) % 5 == 0:
   earned *= 2
  if match_style == "blitz" and not family_active and not campaign_active and not daily_match:
   blitz_last_bonus = mini(15, maxi(0, ceili(remaining_time / 3.0)))
   blitz_total_bonus += blitz_last_bonus
   earned += blitz_last_bonus
  if match_style == "treasure" and not family_active and not campaign_active and not daily_match:
   treasure_keys += 1
   if treasure_doubles > 0:
    earned *= 2
    treasure_doubles -= 1
    treasure_doubled_this_round = true
  if match_style == "vault" and not family_active and not campaign_active and not daily_match:
   vault_pending += earned
  else:
   score += earned
 else:
  if match_style == "vault" and not family_active and not campaign_active and not daily_match:
   vault_lost += vault_pending
   vault_pending = 0
  if match_style in ["survival", "championship"] and not campaign_active and not family_active and not daily_match:
   lives_left -= 1
   if match_style == "championship":
    championship_total_errors += 1
  session_mistakes += 1
  if match_style == "treasure" and treasure_shields > 0 and not family_active and not campaign_active and not daily_match:
   treasure_shields -= 1
   treasure_saved_streak = true
  else:
   streak = 0
 update_offline_opponent()
 if match_style in ["survival", "championship"] and lives_left <= 0 and not family_active and not campaign_active and not daily_match:
  mode_finished_early = true
 clear_ui()
 if is_boss_round():
  label(tr_ui("👑 انتصار على الزعيم!", "👑 BOSS DEFEATED!") if correct else tr_ui("👑 تحدي الزعيم • حاول في المرة القادمة", "👑 BOSS CHALLENGE • TRY AGAIN NEXT TIME"), 28)
 play_feedback("success" if correct else "retry")
 VisualSkin.add_feedback_panel(root, tr_ui("🌟 إجابة صحيحة!", "🌟 CORRECT!") if correct else tr_ui("💡 نتعلم ونكمل", "💡 LEARN AND KEEP GOING"), (("+%d " % earned) + tr_ui("نقطة", "points") + "  ✦  " + answer) if correct else (tr_ui("الإجابة الصحيحة: ", "Correct answer: ") + answer), correct)
 if correct:
  show_celebration(false)
  if match_style == "blitz" and blitz_last_bonus > 0 and not family_active and not campaign_active and not daily_match:
   label(tr_ui("⚡ مكافأة السرعة: +%d نقطة", "⚡ SPEED BONUS: +%d POINTS") % blitz_last_bonus, 20)
  if match_style == "treasure" and not family_active and not campaign_active and not daily_match:
   label(tr_ui("🗝 كسبت مفتاح! معاك %d", "🗝 KEY EARNED! YOU HAVE %d") % treasure_keys, 19)
   if treasure_doubled_this_round:
    label(tr_ui("✨ الكنز ضاعف نقاط السؤال!", "✨ TREASURE BOOST DOUBLED YOUR POINTS!"), 19)
 elif treasure_saved_streak:
  label(tr_ui("🛡 درع الكنز حمى سلسلة الإجابات!", "🛡 TREASURE SHIELD SAVED YOUR STREAK!"), 19)
 if not correct:
  label(tr_ui("تقدر تراجع السؤال لاحقًا من تدريب الأخطاء.", "You can revisit this question in Mistake Practice."), 16)
 if match_style == "vault" and not family_active and not campaign_active and not daily_match:
  label(tr_ui("💎 آمن: %d  •  مؤقت: %d", "💎 SAFE: %d  •  PENDING: %d") % [vault_banked, vault_pending], 19)
 if not answer_feedback.is_empty():
  label(answer_feedback, 18)
 if item.has("image"):
  picture_panel(str(item["image"]), 180)
 label(str(item["explain_" + selected_language]), 20)
 var round_accuracy: int = roundi(100.0 * correct_count / (question_index + 1))
 label(tr_ui("دقة الجولة: %d%%", "Round accuracy: %d%%") % round_accuracy, 17)
 label(tr_ui("سلسلة صحيحة: %d  •  المجموع: %d", "Streak: %d  •  Total: %d") % [streak, score], 17)
 if correct and streak in [3, 5, 10]:
  label(tr_ui("إنجاز رائع! وصلت إلى %d إجابات صحيحة متتالية!", "Great streak! %d correct answers in a row!") % streak, 21)
 if campaign_active:
  profile["checkpoint_" + selected_campaign] = {"next": question_index + 1, "score": score, "correct": correct_count, "streak": streak, "completed": question_index + 1 >= round_bank.size(), "all_ages": family_all_ages}
  save_progress()
  if question_index + 1 < round_bank.size():
   button(tr_ui("استراحة • التقدم محفوظ", "TAKE A BREAK • PROGRESS SAVED"), show_home)
 if match_style == "rival" and not family_active and not campaign_active and not daily_match:
  label(tr_ui("أنت: %d  |  المنافس: %d", "YOU: %d  |  RIVAL: %d") % [score, opponent_points], 20)
 if mode_finished_early:
  label(tr_ui("انتهت المحاولات! شاهد نتيجتك.", "OUT OF LIVES! SEE YOUR RESULTS."), 20)
  finish_match()
  button(tr_ui("شاهد حصيلتك", "VIEW RESULTS"), show_results, GREEN)
 elif question_index + 1 < round_bank.size():
  button(tr_ui("الفصل التالي", "NEXT CHAPTER") if game == 4 and not daily_match else tr_ui("التحدي التالي", "NEXT QUESTION"), next_round, GREEN)
 else:
  finish_match()
  button(tr_ui("شاهد حصيلتك", "VIEW YOUR RESULTS"), show_results, GREEN)

func vault_bank() -> void:
 if vault_locked:
  return
 vault_locked = true
 vault_banked += vault_pending
 score += vault_pending
 vault_pending = 0
 vault_decisions += 1
 show_round()

func vault_risk() -> void:
 if vault_locked:
  return
 vault_locked = true
 vault_decisions += 1
 vault_pending = int(vault_pending * 1.5)
 vault_pending = mini(5000, vault_pending)
 show_round()

func show_vault_checkpoint() -> void:
 clear_ui()
 label(tr_ui("💎 محطة خزنة الجرأة", "💎 RISK VAULT CHECKPOINT"), 30)
 label(tr_ui("محفوظ: %d  •  في المخاطرة: %d", "BANKED: %d  •  AT RISK: %d") % [vault_banked, vault_pending], 22)
 label(tr_ui("احفظ النقاط أو زودها 50%% مع خطر فقدها عند الإجابة الخطأ.", "BANK NOW, OR BOOST THE POT BY 50%% AND RISK LOSING IT ON A WRONG ANSWER."), 19)
 button(tr_ui("🔒 احفظ النقاط", "🔒 BANK POINTS"), vault_bank, GREEN)
 if vault_pending > 0:
  button(tr_ui("🎲 خاطر ×1.5", "🎲 RISK ×1.5"), vault_risk, GOLD)
 else:
  label(tr_ui("اجمع نقاط الأول قبل ما تخاطر", "EARN POINTS BEFORE YOU RISK"), 16)

func show_championship_checkpoint() -> void:
 clear_ui()
 label(tr_ui("🏆 اجتزت مرحلة البطولة!", "🏆 CHAMPIONSHIP STAGE COMPLETE!"), 30)
 label(tr_ui("المرحلة التالية: %d من 3", "NEXT STAGE: %d OF 3") % championship_stage, 22)
 label(tr_ui("⭐ نقاط: %d  •  ❤️ محاولات: %d", "⭐ SCORE: %d  •  ❤️ LIVES: %d") % [score, lives_left], 20)
 label(tr_ui("الزعيم القادم بعد 5 أسئلة. كل إجابة مهمة!", "NEXT BOSS IN FIVE QUESTIONS. EVERY ANSWER COUNTS!"), 18)
 button(tr_ui("⚔ ابدأ المرحلة التالية", "⚔ START NEXT STAGE"), show_round, GOLD)
 button(tr_ui("العودة للرئيسية", "BACK HOME"), show_home, PANEL)

func next_round() -> void:
 question_index += 1
 if match_style == "championship" and question_index % 5 == 0 and question_index < round_bank.size():
  championship_stage_scores.append(score)
  championship_stage = 1 + floori(float(question_index) / 5.0)
  show_championship_checkpoint()
  return
 if match_style == "vault" and not campaign_active and not family_active and not daily_match and question_index % 3 == 0 and question_index < round_bank.size():
  vault_locked = false
  show_vault_checkpoint()
  return
 if match_style == "treasure" and not campaign_active and not family_active and not daily_match and question_index % 4 == 0 and question_index < round_bank.size():
  show_treasure_checkpoint()
  return
 if campaign_active and selected_campaign == "island" and question_index % 6 == 0:
  show_campaign_milestone()
  return
 if not campaign_active and not family_active and question_index % 5 == 0:
  show_session_milestone()
  return
 if family_active:
  family_player = question_index % family_names.size()
  family_ready = false
  streak = 0
 show_round()


# The offline game uses two different cards and a deterministic rule-based rival.
# Real multiplayer must move both card assignments and turn validation server-side.
func build_picture_stage() -> void:
 picture_recorded = false
 picture_question_page = 0
 card_name_page = 0
 var pool: Array = deck_cards()
 var a: int = 0
 for i in range(pool.size()):
  if str(pool[i]["name"]) == str(picture_order[picture_stage - 1]["name"]):
   a = i
   break
 var b := rng.randi_range(0, pool.size() - 2)
 if b >= a:
  b += 1
 my_secret = pool[a].duplicate(true)
 rival_secret = pool[b].duplicate(true)
 asked.clear()
 turns = 0
 rival_step = 0
 rival_turn_count = 0
 rival_used_questions.clear()
 rival_personality = ["explorer", "analyst", "strategist"][clampi(difficulty - 1, 0, 2)]
 picture_done = false
 rival_candidates.clear()
 player_candidates.clear()
 for c in pool:
  if str(c["name"]) != str(my_secret["name"]):
   rival_candidates.append(c.duplicate(true))
  if str(c["name"]) != str(rival_secret["name"]):
   player_candidates.append(c.duplicate(true))
 conversation = ["A new match has started. Your card is hidden from you."]
 show_picture_game()

# Suggest a useful yes/no question using ONLY the public candidate deck.
# Never consult my_secret: doing so would reveal the hidden answer.
func available_picture_questions() -> Array[int]:
 var remaining: Array[int] = []
 for i in range(QUESTIONS.size()):
  if i not in asked:
   remaining.append(i)
 return remaining

func best_picture_question() -> int:
 if player_candidates.size() <= 1:
  return -1
 var best_index: int = -1
 var best_split: int = -1
 for i in available_picture_questions():
  var question: Dictionary = QUESTIONS[i]
  var yes_count: int = 0
  for candidate in player_candidates:
   if candidate[question["key"]] == question["value"]:
    yes_count += 1
  var split_score: int = mini(yes_count, player_candidates.size() - yes_count)
  if split_score > best_split and split_score > 0:
   best_split = split_score
   best_index = i
 return best_index

func picture_question_text(index: int) -> String:
 if selected_language == "tr":
  return str(QUESTIONS[index].get("tr", QUESTIONS[index]["text"]))
 if selected_language == "ar":
  return str(PICTURE_QUESTIONS_AR[index])
 return str(QUESTIONS[index]["text"])

func deduction_progress(remaining: int, total: int) -> void:
 var bar := ProgressBar.new()
 bar.custom_minimum_size.y = 16
 bar.min_value = 0
 bar.max_value = maxi(1, total)
 bar.value = clampi(total - remaining, 0, total)
 bar.show_percentage = false
 bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
 root.add_child(bar)

func show_picture_game() -> void:
 clear_ui()
 active_play_screen = not picture_done
 label(game_title(0), 29)
 label(tr_ui("اكتشاف %d / %d", "DISCOVERY %d / %d") % [picture_stage, picture_stage_count], 19)
 label(tr_ui("منافس محلي • ", "OFFLINE RIVAL • ") + rival_personality_name(), 15)
 label(tr_ui("أسلوب المنافس: ", "RIVAL STYLE: ") + rival_personality_description(), 15)
 label(tr_ui("بطاقة المنافس (يمكنك رؤيتها)", "RIVAL'S SECRET CARD (you can see it)"), 16)
 var art_frame := PanelContainer.new()
 art_frame.custom_minimum_size.y = 215
 art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var portrait_style: StyleBoxFlat = VisualSkin.card(Color("1b2b59"), 24)
 portrait_style.border_color = GOLD
 portrait_style.set_border_width_all(2)
 art_frame.add_theme_stylebox_override("panel", portrait_style)
 root.add_child(art_frame)
 var art := TextureRect.new()
 art.texture = card_texture(str(rival_secret["name"]))
 art.custom_minimum_size = Vector2(0, 195)
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art_frame.add_child(art)
 label(card_display(str(rival_secret["name"])), 30)
 label(artwork_note(str(rival_secret["name"])), 14)
 label(tr_ui("اسأل لتستنتج بطاقتك المخفية؛ الصورة تخص المنافس", "Infer your hidden card; this image belongs to your rival"), 15)
 label(tr_ui("بطاقتك: ؟ ؟ ؟", "YOUR CARD:  ? ? ?"), 27)
 stat_strip(tr_ui("بطاقات محتملة", "POSSIBLE CARDS"), str(player_candidates.size()), tr_ui("الأدوار المتبقية", "TURNS LEFT"), str(maxi(0, picture_turn_limit - turns)))
 deduction_progress(player_candidates.size(), maxi(1, deck_cards().size() - 1))
 for entry in conversation.slice(maxi(0, conversation.size() - 5)):
  label(translate_log(entry), 16)
 if picture_done:
  record_picture_end()
  picture_panel(str(my_secret["name"]), 150)
  label(str(my_secret["fact_" + selected_language]), 18)
  if picture_stage < picture_stage_count:
   button(tr_ui("الصورة التالية • اكتشف المزيد", "NEXT PICTURE • DISCOVER MORE"), next_picture_stage, GREEN)
  else:
   label(tr_ui("اكتملت رحلة الصور", "PICTURE JOURNEY COMPLETE"), 24)
   button(tr_ui("العب مجددًا", "Play again"), start_picture_game, GREEN)
  button(tr_ui("كل الألعاب", "All games"), func(): show_home(), ACCENT)
  return
 label(tr_ui("اسأل سؤالًا إجابته نعم أو لا", "ASK A YES / NO QUESTION"), 19)
 var suggestion: int = best_picture_question()
 if suggestion >= 0:
  var recommended: int = suggestion
  button(tr_ui("💡 سؤال ذكي: ", "💡 SMART QUESTION: ") + picture_question_text(recommended), func(): ask_picture_question(recommended), GREEN)
 elif player_candidates.size() == 1:
  label(tr_ui("وصلت لبطاقة واحدة! جرب تخمينها.", "One card left! Try guessing it."), 18)
 var available: Array[int] = available_picture_questions()
 if not available.is_empty():
  var page_count_questions: int = ceili(float(available.size()) / 6.0)
  picture_question_page = clampi(picture_question_page, 0, page_count_questions - 1)
  for i in available.slice(picture_question_page * 6, mini((picture_question_page + 1) * 6, available.size())):
   var qi: int = i
   button(picture_question_text(qi), func(): ask_picture_question(qi))
  if page_count_questions > 1:
   button(tr_ui("أسئلة أخرى • %d / %d", "MORE QUESTIONS • %d / %d") % [picture_question_page + 1, page_count_questions], func(): picture_question_page = (picture_question_page + 1) % page_count_questions; show_picture_game(), ACCENT)
 var field := LineEdit.new()
 field.add_theme_font_size_override("font_size", int(21 * reading_scale))
 field.placeholder_text = tr_ui("اكتب اسم بطاقتك بالعربية أو الإنجليزية", "Guess your card name")
 field.custom_minimum_size = Vector2(0, 56)
 root.add_child(field)
 button(tr_ui("خمن بطاقتي", "GUESS MY CARD"), func(): submit_picture_guess(field.text), GREEN)
 # The candidate list reflects answers, unlike the old unreachable children-only
 # picker which displayed the full deck and never appeared for audience="all".
 label(tr_ui("أو اختار من البطاقات المحتملة", "OR PICK A POSSIBLE CARD"), 20)
 if not player_candidates.is_empty():
  var candidate_pages: int = ceili(float(player_candidates.size()) / 6.0)
  card_name_page = clampi(card_name_page, 0, candidate_pages - 1)
  for card in player_candidates.slice(card_name_page * 6, mini(card_name_page * 6 + 6, player_candidates.size())):
   var guessed_name: String = str(card["name"])
   button(card_display(guessed_name), func(): submit_picture_guess(guessed_name))
  if candidate_pages > 1:
   button(tr_ui("بطاقات أخرى (%d/%d)", "MORE CARDS (%d/%d)") % [card_name_page + 1, candidate_pages], func(): card_name_page = (card_name_page + 1) % candidate_pages; show_picture_game(), ACCENT)
 button(tr_ui("خروج", "Exit"), confirm_leave_active_game, ACCENT)

func ask_picture_question(qi: int) -> void:
 if picture_done or qi in asked:
  return
 asked.append(qi)
 picture_question_page = 0
 var q: Dictionary = QUESTIONS[qi]
 var answer: bool = my_secret[q["key"]] == q["value"]
 var remaining_player: Array = []
 for candidate in player_candidates:
  if (candidate[q["key"]] == q["value"]) == answer:
   remaining_player.append(candidate)
 player_candidates = remaining_player
 card_name_page = 0
 conversation.append("YOU: " + (str(q["tr"]) if selected_language == "tr" else (str(PICTURE_QUESTIONS_AR[qi]) if selected_language == "ar" else str(q["text"]))))
 conversation.append("RIVAL: " + ("YES" if answer else "NO"))
 advance_rival()
 show_picture_game()
 if picture_done:
  play_feedback("retry")

func rival_personality_name() -> String:
 match rival_personality:
  "explorer":
   return tr_ui("المستكشف", "THE EXPLORER")
  "strategist":
   return tr_ui("الاستراتيجي", "THE STRATEGIST")
  _:
   return tr_ui("المحلل", "THE ANALYST")

func rival_personality_description() -> String:
 match rival_personality:
  "explorer":
   return tr_ui("يسأل أسئلة متنوعة، وقد يختار سؤالًا أقل فاعلية.", "Tries varied questions, sometimes less efficiently.")
  "strategist":
   return tr_ui("يبحث عن السؤال الذي يقسم الاحتمالات بأفضل شكل.", "Seeks the most balanced question to narrow possibilities.")
  _:
   return tr_ui("يوازن بين الاستكشاف وتقليل الاحتمالات.", "Balances exploration and elimination.")

func rival_pick_question() -> Dictionary:
 var options: Array[Dictionary] = []
 for q in QUESTIONS:
  var signature: String = str(q["key"]) + ":" + str(q["value"])
  if signature in rival_used_questions:
   continue
  var yes_count: int = 0
  for candidate in rival_candidates:
   if candidate[q["key"]] == q["value"]:
    yes_count += 1
  var no_count: int = rival_candidates.size() - yes_count
  if yes_count <= 0 or no_count <= 0:
   continue
  var option: Dictionary = q.duplicate(true)
  option["_signature"] = signature
  option["_balance"] = absi(yes_count - no_count)
  options.append(option)
 if options.is_empty():
  return {}
 options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["_balance"]) < int(b["_balance"]))
 var choice_index: int = 0
 if rival_personality == "explorer":
  choice_index = rng.randi_range(0, options.size() - 1)
 elif rival_personality == "analyst":
  choice_index = rng.randi_range(0, mini(2, options.size() - 1))
 return options[choice_index]

func advance_rival() -> void:
 turns += 1
 rival_turn_count += 1
 if turns >= picture_turn_limit:
  conversation.append("DRAW! Turn limit reached. Your card: " + str(my_secret["name"]))
  picture_done = true
  return
 if rival_candidates.is_empty():
  conversation.append("RIVAL: No consistent candidate remains.")
  return
 if rival_candidates.size() == 1:
  var guess_name: String = str(rival_candidates[0]["name"])
  conversation.append("RIVAL GUESS: " + guess_name)
  if guess_name == str(rival_secret["name"]):
   conversation.append("RIVAL WINS! Your card: " + str(my_secret["name"]))
   picture_done = true
  else:
   conversation.append("Wrong rival guess. Keep playing!")
  return
 var question: Dictionary = rival_pick_question()
 if question.is_empty():
  var guess_name: String = str(rival_candidates[0]["name"])
  conversation.append("RIVAL GUESS: " + guess_name)
  if guess_name == str(rival_secret["name"]):
   conversation.append("RIVAL WINS! Your card: " + str(my_secret["name"]))
   picture_done = true
  return
 rival_used_questions.append(str(question["_signature"]))
 var truth: bool = rival_secret[question["key"]] == question["value"]
 conversation.append("RIVAL: " + str(question["text"]))
 conversation.append("YOU (auto): " + ("YES" if truth else "NO"))
 var remaining: Array = []
 for candidate in rival_candidates:
  if (candidate[question["key"]] == question["value"]) == truth:
   remaining.append(candidate)
 rival_candidates = remaining

func submit_picture_guess(value: String) -> void:
 if picture_done:
  return
 var won_now: bool = false
 var guess := value.strip_edges()
 if guess.is_empty():
  conversation.append("Type a guess first.")
 elif matches_card_guess(guess, my_secret):
  won_now = true
  record_picture_win()
  conversation.append("YOU WIN! Your card was " + str(my_secret["name"]) + "!")
  picture_done = true
 else:
  conversation.append("Wrong guess: " + guess)
  var remaining_guesses: Array = []
  for candidate in player_candidates:
   if not matches_card_guess(guess, candidate):
    remaining_guesses.append(candidate)
  player_candidates = remaining_guesses
  card_name_page = 0
  advance_rival()
 show_picture_game()
 play_feedback("celebrate" if won_now else "retry")

func record_picture_end() -> void:
 if picture_recorded:
  return
 picture_recorded = true
 LiveOps.update(profile, false)
 profile["matches"] = int(profile.get("matches", 0)) + 1
 profile["xp"] = int(profile.get("xp", 0)) + 5
 save_progress()

var answer_feedback: String = ""

func load_catalog() -> void:
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
 if data is Dictionary:
  CARDS = data.get("cards", [])
  QUESTIONS = data.get("questions", [])
 CARD_NAMES_AR.clear()
 PICTURE_QUESTIONS_AR.clear()
 for card in CARDS:
  CARD_NAMES_AR[str(card["name"])] = str(card["ar"])
 for question in QUESTIONS:
  PICTURE_QUESTIONS_AR.append(str(question["ar"]))

func matches_card_guess(value: String, card: Dictionary) -> bool:
 var aliases: Array = [card["name"], card["ar"], card["en"], card["tr"]] + card.get("aliases", [])
 for alias in aliases:
  if normal_answer(value) == normal_answer(str(alias)):
   return true
 return false

func picture_panel(id: String, height: int) -> void:
 var art := TextureRect.new()
 art.texture = card_texture(id)
 art.custom_minimum_size.y = height
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 root.add_child(art)
 label(artwork_note(id), 13)

func select_answer(index: int) -> void:
 var item: Dictionary = round_bank[question_index]
 var choices: Array = item["choices_" + selected_language]
 var feedback: Array = item.get("feedback_" + selected_language, [])
 answer_feedback = tr_ui("اختيارك: ", "Your choice: ") + str(choices[index])
 if index < feedback.size():
  answer_feedback += "\n" + str(feedback[index])
 finish_round(index == int(item["correct"]), str(choices[int(item["correct"])]))

func toggle_favorite() -> void:
 var favorites: Array = profile.get("favorites", [])
 if game in favorites:
  favorites.erase(game)
 else:
  favorites.append(game)
 profile["favorites"] = favorites
 save_progress()
 show_modes(game)

func start_review() -> void:
 match_style = "classic" # Practice should never inherit a blitz clock or treasure economy.
 quick_match_active = false
 campaign_active = false
 family_active = false
 daily_match = false
 game = 5
 question_index = 0
 score = 0
 streak = 0
 correct_count = 0
 session_best_streak = 0
 session_mistakes = 0
 round_bank.clear()
 var missed: Array = profile.get("missed", [])
 for index in [1, 2, 3, 4, 5, 6, 7, 9]:
  for item in eligible_questions(index, false):
   if str(item.get("id", "")) in missed:
    round_bank.append(item.duplicate(true))
 shuffle_items(round_bank)
 round_bank = round_bank.slice(0, session_length)
 show_round()

func show_gallery(page: int) -> void:
 clear_ui()
 label(tr_ui("معرض الاكتشاف", "DISCOVERY GALLERY"), 30)
 label(tr_ui("صور ومعلومات تساعدك في ألعاب الاستنتاج", "Pictures and facts for your deduction adventures"), 18)
 for i in range(page * 4, mini(page * 4 + 4, CARDS.size())):
  var card: Dictionary = CARDS[i]
  picture_panel(str(card["name"]), 180)
  label(card_display(str(card["name"])), 24)
  label(str(card["fact_" + selected_language]), 18)
 if page > 0:
  button(tr_ui("السابق", "PREVIOUS"), func(): show_gallery(page - 1))
 if (page + 1) * 4 < CARDS.size():
  button(tr_ui("صور جديدة", "MORE PICTURES"), func(): show_gallery(page + 1), GREEN)
 button(tr_ui("تحدي الصور والمعلومات", "PICTURE QUIZ"), func(): game = 5; selected_topic = "visual"; show_modes(5), ACCENT)
 button(tr_ui("الرئيسية", "HOME"), show_home)

func translate_turkish_log(entry: String) -> String:
 var value: String = entry
 for question in QUESTIONS:
  value = value.replace(str(question["text"]), str(question["tr"]))
 var mapping: Dictionary = {
  "A new match has started. Your card is hidden from you.": "Yeni oyun başladı. Kartın senden gizli.",
  "RIVAL GUESS:": "RAKİBİN TAHMİNİ:", "YOU (auto):": "SEN (otomatik):",
  "YOU WIN!": "KAZANDIN!", "RIVAL WINS!": "RAKİP KAZANDI!", "DRAW!": "BERABERE!",
  "Turn limit reached. Your card:": "Tur sınırına ulaşıldı. Kartın:",
  "Your card:": "Kartın:", "Your card was": "Kartın şuydu:",
  "Wrong guess:": "Yanlış tahmin:", "Type a guess first.": "Önce bir tahmin yaz.",
  "Wrong AI guess. Keep playing!": "Rakip yanlış tahmin etti. Devam et!",
  "YOU:": "SEN:", "RIVAL:": "RAKİP:", "YES": "EVET", "NO": "HAYIR"
 }
 for key in mapping:
  value = value.replace(str(key), str(mapping[key]))
 for card in CARDS:
  value = value.replace(str(card["name"]), str(card["tr"]))
 return value

func show_languages() -> void:
 clear_ui()
 label(tr_ui("اختر اللغة", "CHOOSE LANGUAGE"), 30)
 var names: Dictionary = {"ar": "العربية", "en": "English"}
 for key in ["ar", "en"]:
  var chosen: String = str(key)
  button(str(names[key]), func(): selected_language = chosen; save_progress(); show_home(), GREEN if chosen == selected_language else PANEL)
 button(tr_ui("العودة", "BACK"), show_home)

var deck: String = "all"
var player_candidates: Array = []
var card_name_page: int = 0
var order_picks: Array[int] = []
var order_label: Label
var order_buttons: Array[Button] = []
var memory_cards: Array[String] = []
var memory_matched: Array[int] = []
var memory_open: Array[int] = []
var memory_buttons: Array[Button] = []
var memory_moves: int = 0
var memory_done: bool = false
var memory_busy: bool = false
var memory_generation: int = 0
var memory_status: Label

func deck_title(key: String = "") -> String:
 if key.is_empty():
  key = deck
 var ar: Dictionary = {"all": "كل الصور", "Animal": "الحيوانات", "Food": "الأطعمة", "Object": "الأدوات", "Place": "المعالم"}
 var en: Dictionary = {"all": "All pictures", "Animal": "Animals", "Food": "Foods", "Object": "Objects", "Place": "Landmarks"}
 return tr_ui(str(ar.get(key, key)), str(en.get(key, key)))

func deck_cards() -> Array:
 var pool: Array = []
 for card in CARDS:
  if deck == "all" or str(card["category"]) == deck:
   pool.append(card)
 return pool

func show_decks() -> void:
 clear_ui()
 label(tr_ui("اختر مجموعة الصور", "CHOOSE A CARD COLLECTION"), 28)
 for key in ["all", "Animal", "Food", "Object", "Place"]:
  var chosen: String = str(key)
  button(deck_title(chosen), func(): deck = chosen; show_modes(game), GREEN if deck == chosen else PANEL)
 button(tr_ui("العودة", "BACK"), func(): show_modes(game))

func show_order_choices(item: Dictionary) -> void:
 order_picks.clear()
 order_buttons.clear()
 order_label = label(tr_ui("اضغط الخطوات حسب ترتيبها الصحيح", "TAP STEPS IN THE CORRECT ORDER"), 18)
 var steps: Array = item["steps_" + selected_language]
 var order: Array = range(steps.size())
 shuffle_items(order)
 # Avoid presenting an already solved ordering.
 if order == range(steps.size()):
  order.reverse()
 order_buttons.resize(steps.size())
 for value in order:
  var index: int = int(value)
  order_buttons[index] = button(str(steps[index]), func(): pick_order_step(index))
 button(tr_ui("تراجع خطوة", "UNDO STEP"), undo_order_step)
 button(tr_ui("تحقق من الترتيب", "CHECK ORDER"), submit_order, GREEN)

func pick_order_step(index: int) -> void:
 if round_finished or index in order_picks or index < 0 or index >= order_buttons.size():
  return
 order_picks.append(index)
 order_buttons[index].disabled = true
 update_order_label()

func undo_order_step() -> void:
 if round_finished or order_picks.is_empty():
  return
 var index: int = order_picks.pop_back()
 order_buttons[index].disabled = false
 update_order_label()

func update_order_label() -> void:
 var steps: Array = round_bank[question_index]["steps_" + selected_language]
 var chosen: Array[String] = []
 for index in order_picks:
  chosen.append(str(steps[index]))
 order_label.text = " → ".join(chosen)

func submit_order() -> void:
 if round_finished:
  return
 var steps: Array = round_bank[question_index]["steps_" + selected_language]
 if order_picks.size() != steps.size():
  order_label.text = tr_ui("اختر كل الخطوات أولًا", "SELECT ALL STEPS FIRST")
  return
 var correct: bool = true
 for i in range(order_picks.size()):
  if order_picks[i] != i:
   correct = false
 var answer: Array[String] = []
 for step in steps:
  answer.append(str(step))
 answer_feedback = tr_ui("ترتيبك: ", "YOUR ORDER: ") + order_label.text
 finish_round(correct, " → ".join(answer))

func build_memory_board() -> void:
 memory_generation += 1
 family_active = false
 daily_match = false
 memory_cards.clear()
 memory_matched.clear()
 memory_open.clear()
 memory_moves = 0
 memory_done = false
 memory_busy = false
 var pool: Array = deck_cards().duplicate(true)
 shuffle_items(pool)
 var pairs: int = mini(pool.size(), 4 + difficulty * 2)
 for card in pool.slice(0, pairs):
  memory_cards.append(str(card["name"]))
  memory_cards.append(str(card["name"]))
 var shuffled: Array = memory_cards.duplicate()
 shuffle_items(shuffled)
 memory_cards.assign(shuffled)
 show_memory()

func show_memory() -> void:
 clear_ui()
 active_play_screen = not memory_done
 label(game_title(8), 30)
 label(tr_ui("لوحة %d / %d", "BOARD %d / %d") % [memory_stage, memory_stage_count], 18)
 label(deck_title() + " • " + difficulty_name(difficulty), 16)
 label(tr_ui("اكشف صورتين متطابقتين. لا يوجد حد للوقت.", "FIND TWO MATCHING PICTURES. NO TIME LIMIT."), 20)
 memory_status = label("", 18)
 var grid := GridContainer.new()
 grid.columns = 3 if memory_cards.size() <= 12 else 4
 grid.add_theme_constant_override("h_separation", 8)
 grid.add_theme_constant_override("v_separation", 8)
 root.add_child(grid)
 memory_buttons.clear()
 for i in range(memory_cards.size()):
  var index: int = i
  var tile := Button.new()
  tile.text = "?"
  tile.custom_minimum_size = Vector2(0, 94)
  tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  tile.expand_icon = true
  tile.add_theme_constant_override("icon_max_width", 60)
  tile.add_theme_font_size_override("font_size", 30)
  tile.add_theme_stylebox_override("normal", panel_style(PANEL))
  tile.pressed.connect(func(): flip_memory(index))
  grid.add_child(tile)
  memory_buttons.append(tile)
 update_memory_tiles()
 button(tr_ui("الرئيسية", "HOME"), confirm_leave_active_game)

func update_memory_tiles() -> void:
 memory_status.text = tr_ui("أزواج: %d / %d • محاولات: %d", "PAIRS: %d / %d • ATTEMPTS: %d") % [memory_matched.size() / 2, memory_cards.size() / 2, memory_moves]
 for i in range(memory_buttons.size()):
  if i in memory_matched or i in memory_open:
   memory_buttons[i].text = ""
   memory_buttons[i].icon = card_texture(memory_cards[i])
   memory_buttons[i].tooltip_text = card_display(memory_cards[i])
  else:
   memory_buttons[i].text = "?"
   memory_buttons[i].icon = null
   memory_buttons[i].tooltip_text = ""
  memory_buttons[i].disabled = memory_busy or i in memory_matched or memory_done

func flip_memory(index: int) -> void:
 if memory_busy or memory_done or index < 0 or index >= memory_cards.size() or index in memory_open or index in memory_matched:
  return
 memory_open.append(index)
 if memory_open.size() == 1:
  update_memory_tiles()
  return
 memory_moves += 1
 if memory_cards[memory_open[0]] == memory_cards[memory_open[1]]:
  memory_matched.append_array(memory_open)
  memory_open.clear()
  if memory_matched.size() == memory_cards.size():
   finish_memory()
  else:
   update_memory_tiles()
 else:
  memory_busy = true
  update_memory_tiles()
  var generation: int = memory_generation
  var reveal_time: float = 1.6 if difficulty == 1 else (1.2 if difficulty == 2 else 0.9)
  await get_tree().create_timer(reveal_time).timeout
  if generation != memory_generation or not is_instance_valid(memory_status):
   return
  memory_open.clear()
  memory_busy = false
  update_memory_tiles()

func finish_memory() -> void:
 if memory_done:
  return
 memory_done = true
 var pairs: int = memory_cards.size() / 2
 var earned: int = maxi(10, pairs * 15 - maxi(0, memory_moves - pairs) * 2)
 LiveOps.update(profile, true)
 profile["matches"] = int(profile.get("matches", 0)) + 1
 profile["wins"] = int(profile.get("wins", 0)) + 1
 profile["xp"] = int(profile.get("xp", 0)) + earned
 profile["memory_wins"] = int(profile.get("memory_wins", 0)) + 1
 profile["best_8"] = maxi(int(profile.get("best_8", 0)), earned)
 save_progress()
 clear_ui()
 label(tr_ui("اكتملت الصور!", "ALL PAIRS FOUND!"), 32)
 label(tr_ui("أزواج: %d / %d • محاولات: %d", "PAIRS: %d / %d • ATTEMPTS: %d") % [pairs, pairs, memory_moves], 21)
 label(tr_ui("+%d خبرة", "+%d XP") % earned, 25)
 var memory_accuracy: int = roundi(100.0 * pairs / maxi(pairs, memory_moves))
 label(tr_ui("كفاءة المطابقة: %d%%", "MATCH EFFICIENCY: %d%%") % memory_accuracy, 18)
 label(result_medal(memory_accuracy), 24)
 xp_progress()
 if memory_stage < memory_stage_count:
  button(tr_ui("اللوحة التالية • أكمل الرحلة", "NEXT BOARD • KEEP EXPLORING"), next_memory_board, GREEN)
 else:
  label(tr_ui("أكملت رحلة الذاكرة!", "MEMORY JOURNEY COMPLETE!"), 24)
  button(tr_ui("العب مجددًا", "Play again"), start_memory, GREEN)
 button(tr_ui("اختر مجموعة أخرى", "CHOOSE ANOTHER COLLECTION"), func(): show_modes(8), ACCENT)
 button(tr_ui("الرئيسية", "HOME"), show_home)

var mixed_levels: bool = false
var selected_campaign: String = "island"
var campaign_active: bool = false
var campaign_data: Dictionary = {}
var memory_stage: int = 1
var memory_stage_count: int = 3

func campaign_title() -> String:
 return tr_ui("جزيرة الاكتشاف • 30 مرحلة", "DISCOVERY ISLAND • 30 STAGES") if selected_campaign == "island" else tr_ui("أرشيف الأسرار", "THE SECRET ARCHIVE")

func show_campaigns() -> void:
 clear_ui()
 label(tr_ui("اختر رحلتك", "CHOOSE YOUR JOURNEY"), 30)
 for key in ["island", "archive"]:
  var chosen: String = str(key)
  button(tr_ui("جزيرة الاكتشاف • 30 مرحلة", "DISCOVERY ISLAND • 30 STAGES") if chosen == "island" else tr_ui("أرشيف الأسرار", "THE SECRET ARCHIVE"), func(): selected_campaign = chosen; save_progress(); show_modes(4), GREEN if chosen == selected_campaign else PANEL)
 button(tr_ui("العودة", "BACK"), func(): show_modes(4))

func start_campaign() -> void:
 game = 4
 campaign_active = true
 mixed_levels = false
 selection_notice = false
 family_active = false
 daily_match = false
 campaign_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaigns.json"))
 round_bank.clear()
 for item in eligible_questions(4, false):
  if (str(item.get("campaign", "")) == selected_campaign) or (selected_campaign == "archive" and not item.has("campaign")):
   round_bank.append(item.duplicate(true))
 var saved: Dictionary = profile.get("checkpoint_" + selected_campaign, {})
 var resume: bool = not bool(saved.get("completed", false)) and int(saved.get("next", 0)) < round_bank.size() and (selected_campaign == "island" or bool(saved.get("all_ages", family_all_ages)) == family_all_ages)
 question_index = int(saved.get("next", 0)) if resume else 0
 score = int(saved.get("score", 0)) if resume else 0
 correct_count = int(saved.get("correct", 0)) if resume else 0
 streak = int(saved.get("streak", 0)) if resume else 0
 show_round()

func show_campaign_milestone() -> void:
 clear_ui()
 label(tr_ui("اكتشاف جديد!", "A NEW DISCOVERY!"), 32)
 label(tr_ui("قطع الخريطة: %d / 5", "MAP PIECES: %d / 5") % (question_index / 6), 23)
 var pieces := ProgressBar.new()
 pieces.max_value = 5
 pieces.value = question_index / 6
 pieces.show_percentage = false
 pieces.custom_minimum_size.y = 14
 root.add_child(pieces)
 var act: int = mini(4, question_index / 6)
 campaign_scene(act, 210)
 label(str(campaign_data["acts"][selected_language][act]), 26)
 label(tr_ui("الخطوة التالية تقربك من نور المنارة", "THE NEXT STEP BRINGS THE LIGHTHOUSE CLOSER"), 19)
 button(tr_ui("أكمل المغامرة", "CONTINUE THE ADVENTURE"), show_round, GREEN)
 button(tr_ui("استراحة • التقدم محفوظ", "TAKE A BREAK • PROGRESS SAVED"), show_home)

func start_memory() -> void:
 campaign_active = false
 memory_stage = 1
 memory_stage_count = clampi(ceili(session_length / 4.0), 3, 8)
 build_memory_board()

func next_memory_board() -> void:
 if not memory_done or memory_stage >= memory_stage_count:
  return
 memory_stage += 1
 build_memory_board()

func show_session_milestone() -> void:
 clear_ui()
 label(tr_ui("محطة اكتشاف جديدة", "ANOTHER DISCOVERY CHECKPOINT"), 30)
 label(tr_ui("أكملت %d من %d نشاطًا", "YOU COMPLETED %d OF %d ACTIVITIES") % [question_index, round_bank.size()], 23)
 label(tr_ui("سلسلة صحيحة: %d  •  المجموع: %d", "Streak: %d  •  Total: %d") % [streak, score], 18)
 button(tr_ui("أكمل الرحلة", "CONTINUE THE JOURNEY"), show_round, GREEN)
 button(tr_ui("العودة", "BACK"), show_home)

var picture_stage: int = 1
var picture_stage_count: int = 5
var picture_order: Array = []

func start_picture_game() -> void:
 campaign_active = false
 picture_stage = 1
 picture_order = deck_cards().duplicate(true)
 shuffle_items(picture_order)
 picture_stage_count = mini(picture_order.size(), clampi(ceili(session_length / 2.0), 5, 15))
 build_picture_stage()

func next_picture_stage() -> void:
 if not picture_done or picture_stage >= picture_stage_count:
  return
 picture_stage += 1
 build_picture_stage()

func campaign_scene(act: int, height: int = 180) -> void:
 var scenes: Array = campaign_data.get("scenes", [])
 if act >= 0 and act < scenes.size() and ResourceLoader.exists(str(scenes[act])):
  var art := TextureRect.new()
  art.texture = cached_texture(str(scenes[act]))
  art.custom_minimum_size.y = height
  art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
  root.add_child(art)
  label(tr_ui("مشهد خيالي مرسوم ومولد بالذكاء الاصطناعي", "FICTIONAL ILLUSTRATED SCENE • AI-GENERATED"), 12)
 else:
  picture_panel(str(campaign_data["images"][clampi(act, 0, 4)]), height)

func show_privacy_and_ads() -> void:
 clear_ui()
 label(tr_ui("🛡 الخصوصية والإعلانات", "🛡 PRIVACY & ADS"), 30)
 label(tr_ui("الإعلانات مغلقة افتراضيًا. قد تتوفر إعلانات تجريبية اختيارية للكبار فقط بعد تثبيت SDK.", "Ads are off by default. Optional test ads for adults require the verified SDK."), 19)
 label(tr_ui("ملفات الأطفال والمراهقين لا تعرض إعلانات. تُمنح العملات بعد إثبات مشاهدة الإعلان من SDK فقط.", "No ads for children or teens. Coins require a real SDK-earned callback."), 17)
 label(tr_ui("قد تتطلب مباريات الأونلاين اتصالًا بسيرفر اللعبة. بيانات المباراة تُستخدم لتشغيل الغرفة؛ راجع سياسة الخصوصية النهائية قبل النشر.", "Online matches connect to the game server. Match data supports room operation; review the final privacy policy before release."), 17)
 label(tr_ui("إضافة AdMob الأصلية مثبتة. الإعلانات التجريبية للبالغين في نسخة التطوير فقط، والإعلانات الإنتاجية مغلقة.", "The native AdMob add-on is installed. Adult test ads are development-only; production ads are disabled."), 16)
 button(tr_ui("قراءة سياسة الخصوصية كاملة", "READ FULL PRIVACY POLICY"), func(): OS.shell_open("https://iroaa15-bot.github.io/GamingHub/privacy.html"), PANEL)
 button(tr_ui("تفاصيل حالة الإعلانات", "AD INTEGRATION STATUS"), show_ad_status, PANEL)
 if PoingAdsBridge.privacy_options_required():
  button(tr_ui("خيارات موافقة الإعلانات", "AD CONSENT OPTIONS"), PoingAdsBridge.show_privacy_options, PANEL)
 button(tr_ui("العودة للرئيسية", "BACK HOME"), show_home, GOLD)

func show_ad_status() -> void:
 clear_ui()
 label(tr_ui("الإعلانات والأرباح", "ADS & MONETIZATION"), 32)
 label(tr_ui("لا توجد إعلانات إنتاج أو أرباح. الإعلانات التجريبية تتطلب SDK واختبار الهاتف.", "No production ads or revenue. Test ads require SDK and device verification."), 19)
 label(AdManager.status_text(), 16)
 label(tr_ui("رصيد العملات: %d", "COINS BALANCE: %d") % int(profile.get("coins", 0)), 20)
 label(tr_ui("ملفات الأطفال والمراهقين والعائلات: بدون إعلانات. لا مكافأة قبل إشارة المشاهدة الحقيقية.", "Children, teens and families: no ads. Rewards require the native earned callback."), 17)
 if age_group == "18plus" and AdManager.is_ad_eligible():
  button(tr_ui("🎬 إعلان تجريبي اختياري • 50 عملة", "🎬 OPTIONAL TEST AD • 50 COINS"), func(): AdManager.request_rewarded_ad(), GREEN)
 else:
  label(tr_ui("الإعلانات غير متاحة حاليًا. لا يلزم إعلان للعب.", "Ads are unavailable. You can play without ads."), 16)
 button(tr_ui("تعديل الفئة العمرية", "CHANGE AGE GROUP"), show_age_group_selection, PANEL)
 button(tr_ui("العودة للرئيسية", "BACK HOME"), show_home)


func open_guess_multiplayer() -> void:
 if age_group == "under13" or age_group == "unknown":
  show_home()
  return
 get_tree().change_scene_to_file("res://scenes/Multiplayer.tscn")

