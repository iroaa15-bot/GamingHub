extends SceneTree

const Bridge = preload("res://scripts/voice_signaling_bridge.gd")
var sent: Array[Dictionary] = []
var offers: Array[String] = []

func _initialize() -> void:
 var bridge = Bridge.new()
 bridge.configure(Callable(self, "_record"))
 assert(not bridge.ready())
 assert(not bridge.send_description("offer", "example"))
 bridge.set_consent(true, false, true)
 assert(not bridge.ready())
 assert(not bridge.send_candidate("candidate:1", "audio", 0))
 bridge.set_consent(true, true, true)
 assert(bridge.ready())
 assert(bridge.send_description("offer", "example"))
 assert(sent.size() == 1)
 assert(sent[0].get("type") == "voice_offer")
 assert(not bridge.send_description("invalid", "example"))
 bridge.remote_description.connect(Callable(self, "_offer"))
 bridge.handle_server_message({"type":"voice_offer","payload":{"sdp":"remote"}})
 assert(offers.size() == 1 and offers[0] == "remote")
 bridge.set_consent(false, true, true)
 bridge.handle_server_message({"type":"voice_offer","payload":{"sdp":"blocked"}})
 assert(offers.size() == 1)
 assert(not bridge.send_description("answer", "blocked"))
 bridge.reset()
 assert(not bridge.ready())
 print("VOICE_CLIENT_SMOKE_PASS")
 quit(0)

func _record(msg: Dictionary) -> void:
 sent.append(msg)

func _offer(_kind: String, sdp: String) -> void:
 offers.append(sdp)
