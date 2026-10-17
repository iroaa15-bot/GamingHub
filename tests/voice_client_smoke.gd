extends SceneTree

const Bridge = preload("res://scripts/voice_signaling_bridge.gd")
var sent: Array[Dictionary] = []
var offers: Array[String] = []
var candidates: Array[String] = []
var rejected: Array[String] = []

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
 assert(bridge.send_candidate("candidate:1", "audio", 0))
 assert(sent.size() == 2 and sent[1].get("type") == "voice_ice")
 assert(not bridge.send_candidate("", "audio", 0))
 assert(not bridge.send_candidate("candidate:1", "audio", -1))
 bridge.remote_description.connect(Callable(self, "_offer"))
 bridge.remote_candidate.connect(Callable(self, "_candidate"))
 bridge.signaling_rejected.connect(Callable(self, "_rejected"))
 bridge.handle_server_message({"type":"voice_offer","payload":{"sdp":"remote"}})
 assert(offers.size() == 1 and offers[0] == "remote")
 bridge.handle_server_message({"type":"voice_ice","payload":{"candidate":"remote-candidate","sdp_mid":"audio","sdp_mline_index":0}})
 assert(candidates.size() == 1 and candidates[0] == "remote-candidate")
 bridge.handle_server_message({"type":"voice_offer","payload":{"sdp":""}})
 assert(rejected.size() == 1)
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

func _candidate(candidate: String, _mid: String, _line: int) -> void:
 candidates.append(candidate)

func _rejected(reason: String) -> void:
 rejected.append(reason)
