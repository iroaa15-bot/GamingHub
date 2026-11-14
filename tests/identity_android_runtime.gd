extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var auth=load("res://scripts/network/gaminghub_auth.gd").new()
 root.add_child(auth)
 assert(not auth.configure("http://insecure.example"))
 assert(not auth.configure("https://user:secret@example.test"))
 assert(auth.configure("https://example.test"))
 auth._remember_token("session-a")
 assert(auth.configure("https://another.example.test"))
 assert(auth.session_token.is_empty())
 var content=root.get_node("PublishedContent")
 var q={"id":"pub_test","game_id":"5","level":1,"correct":0,"ar":"سؤال","en":"Question","choices_ar":["أ","ب","ج","د"],"choices_en":["A","B","C","D"]}
 assert(content._valid(q))
 var main=load("res://scripts/main.gd").new()
 root.add_child(main)
 await process_frame
 var original: int=main.question_bank["5"].size()
 content.questions={"5":[q]};content.changed.emit()
 assert(main.question_bank["5"].size()==original+1)
 content.questions={};content.changed.emit()
 assert(main.question_bank["5"].size()==original)
 var screen=load("res://scripts/account_screen.gd").new()
 root.add_child(screen)
 await process_frame
 assert(screen.server_field!=null and screen.password_field.secret)
 screen.queue_free();main.queue_free();auth.queue_free()
 await process_frame
 print("IDENTITY_ANDROID_RUNTIME_PASS: HTTPS, origin isolation, published add/revoke, local fallback, account screen")
 quit(0)
