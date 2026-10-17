extends RefCounted
## Signaling adapter for an Android native WebRTC *audio media* implementation.
## This does not capture, send or play microphone audio by itself.

signal remote_description(kind: String, sdp: String)
signal remote_candidate(candidate: String, sdp_mid: String, sdp_mline_index: int)
signal signaling_rejected(reason: String)

var local_consent := false
var remote_consent := false
var room_active := false
var _send_message: Callable

func configure(send_message: Callable) -> void:
 _send_message = send_message

func set_consent(local_enabled: bool, remote_enabled: bool, active_room: bool) -> void:
 local_consent = local_enabled
 remote_consent = remote_enabled
 room_active = active_room

func ready() -> bool:
 return room_active and local_consent and remote_consent

func reset() -> void:
 local_consent = false
 remote_consent = false
 room_active = false

func send_description(kind: String, sdp: String) -> bool:
 if not ready() or not _send_message.is_valid():
  return false
 if kind != "offer" and kind != "answer":
  return false
 if sdp.is_empty() or sdp.length() > 5500:
  return false
 _send_message.call({"type": "voice_" + kind, "payload": {"sdp": sdp}})
 return true

func send_candidate(candidate: String, sdp_mid: String, sdp_mline_index: int) -> bool:
 if not ready() or not _send_message.is_valid():
  return false
 if candidate.is_empty() or candidate.length() > 4096:
  return false
 if sdp_mid.length() > 128 or sdp_mline_index < 0:
  return false
 _send_message.call({"type": "voice_ice", "payload": {"candidate": candidate, "sdp_mid": sdp_mid, "sdp_mline_index": sdp_mline_index}})
 return true

func handle_server_message(msg: Dictionary) -> void:
 if not ready():
  return
 var kind := str(msg.get("type", ""))
 var payload: Variant = msg.get("payload", {})
 if not (payload is Dictionary):
  signaling_rejected.emit("Invalid payload")
  return
 if kind == "voice_offer" or kind == "voice_answer":
  var sdp: Variant = payload.get("sdp", null)
  if not (sdp is String) or sdp.is_empty() or sdp.length() > 5500:
   signaling_rejected.emit("Invalid SDP")
   return
  remote_description.emit("offer" if kind == "voice_offer" else "answer", sdp)
 elif kind == "voice_ice":
  var candidate: Variant = payload.get("candidate", null)
  var mid: Variant = payload.get("sdp_mid", "")
  var line: Variant = payload.get("sdp_mline_index", 0)
  if not (candidate is String) or candidate.is_empty() or candidate.length() > 4096 or not (mid is String) or not (line is int):
   signaling_rejected.emit("Invalid ICE")
   return
  remote_candidate.emit(candidate, mid, line)
