extends Node
## Local microphone capture probe for Photo Duel staging only.
## Does not connect to existing voice servers or alter production.
signal microphone_level(value: float)
signal audio_frame(pcm: String)
var voice_enabled := false
const VOICE_RATE := 48000.0
var resample_phase := 0.0
var voice_buffer := PackedVector2Array()
var capture: AudioEffectCapture
var player: AudioStreamPlayer
var enabled := false

func _ready() -> void:
	var bus := AudioServer.get_bus_index("PhotoDuelMic")
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "PhotoDuelMic")
	# Keep bus unmuted for capture; attenuate output to prevent feedback.
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, 0.0)
	var silent := AudioServer.get_bus_index("PhotoDuelSilent")
	if silent == -1:
		AudioServer.add_bus()
		silent = AudioServer.bus_count - 1
		AudioServer.set_bus_name(silent, "PhotoDuelSilent")
	AudioServer.set_bus_mute(silent, true)
	AudioServer.set_bus_send(bus, "PhotoDuelSilent")
	capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, capture)
	player = AudioStreamPlayer.new()
	player.stream = AudioStreamMicrophone.new()
	player.bus = "PhotoDuelMic"
	add_child(player)

func start_voice() -> bool:
	voice_enabled = start_probe()
	return voice_enabled

func stop_voice() -> void:
	voice_enabled = false
	stop_probe()

func start_probe() -> bool:
	if OS.get_name() == "Android" and not "android.permission.RECORD_AUDIO" in OS.get_granted_permissions():
		OS.request_permission("android.permission.RECORD_AUDIO")
		return false
	enabled = true
	player.play()
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		stop_voice()

func _exit_tree() -> void:
	stop_voice()
	for bus_name in ["PhotoDuelMic", "PhotoDuelSilent"]:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus >= 0:
			AudioServer.remove_bus(bus)

func stop_probe() -> void:
	enabled = false
	resample_phase = 0.0
	voice_buffer.clear()
	player.stop()
	# AudioEffectCapture.clear_buffer() fails while the audio effect is active.
	# Captured frames are drained when recording resumes.

func _process(_delta: float) -> void:
	if not enabled or capture == null:
		return
	var available := capture.get_frames_available()
	if available <= 0:
		return
	var frames := capture.get_buffer(mini(available, 1024))
	var peak := 0.0
	for frame in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	microphone_level.emit(peak)
	if voice_enabled:
		var ratio := VOICE_RATE / maxf(float(AudioServer.get_mix_rate()), 1.0)
		for frame in frames:
			resample_phase += ratio
			while resample_phase >= 1.0:
				voice_buffer.append(frame)
				resample_phase -= 1.0
		while voice_buffer.size() >= 960:
			var pcm := PackedByteArray()
			for i in range(960):
				var sample := int(clampf(voice_buffer[i].x, -1.0, 1.0) * 32767.0)
				pcm.append(sample & 255)
				pcm.append((sample >> 8) & 255)
			voice_buffer = voice_buffer.slice(960)
			audio_frame.emit(Marshalls.raw_to_base64(pcm))
