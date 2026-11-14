extends SceneTree
func _initialize() -> void:
 var loader=load("res://scripts/approved_content.gd")
 var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
 var bank: Dictionary=loader.questions(raw)
 var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://release/master_integration_20261102/question_policy_report.json"))
 var ok: bool=true
 for game in bank:
  ok=ok and bank[game].size()==int(expected.playable_by_game[game])
  for item in bank[game]:ok=ok and loader.question_allowed(item)
 ok=ok and not loader.question_allowed({"id":"core_3_0","ar":"2، 4، 6"}) and not loader.question_allowed({"topic":"logic","ar":"ما ناتج 5 + 3؟"}) and loader.question_allowed({"topic":"space","ar":"أي كوكب في مجموعتنا الشمسية؟"})
 ok=ok and loader.question_allowed({"topic":"numbers","ar":"في أي عام انتهت الحرب العالمية الثانية؟ 1945 أم 1940؟"}) and loader.question_allowed({"topic":"logic","ar":"تجاوزت صاحب المركز الثاني. ما مركزك؟"})
 print("QUESTION_POLICY_CLIENT_SERVER_MATCH ",ok," ",expected.playable_by_game)
 quit(0 if ok else 1)
