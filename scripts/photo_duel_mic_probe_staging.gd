extends Node
## Local microphone capture probe for Photo Duel staging only.
## Does not connect to existing voice servers or alter production.
signal microphone_level(value: float)
signal audio_frame(pcm: String)
var voice_enabled := false
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
	AudioServer.set_bus_volume_db(bus, -80.0)
	capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, capture)
	player = AudioStreamPlayer.new()
	player.stream = AudioStreamMicrophone.new()
	player.bus = "PhotoDuelMic"
	add_child(player)

func start_voice() -> void:
	voice_enabled = true
	start_probe()

func stop_voice() -> void:
	voice_enabled = false
	stop_probe()

func start_probe() -> void:
	enabled = true
	player.play()

func stop_probe() -> void:
	enabled = false
	voice_buffer.clear()
	player.stop()
	if capture:
		capture.clear_buffer()

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
		for frame in frames:
			voice_buffer.append(frame)
		while voice_buffer.size() >= 960:
			var pcm := PackedByteArray()
			for i in range(960):
				var sample := int(clampf(voice_buffer[i].x, -1.0, 1.0) * 32767.0)
				pcm.append(sample & 255)
				pcm.append((sample >> 8) & 255)
			voice_buffer = voice_buffer.slice(960)
			audio_frame.emit(Marshalls.raw_to_base64(pcm))
