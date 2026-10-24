extends Node
## Isolated Photo Duel PCM16 playback. Uses the Godot output mixer; no production audio.
var speaker: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var sample_rate := 48000.0

func _ready() -> void:
	sample_rate = AudioServer.get_mix_rate()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = sample_rate
	generator.buffer_length = 0.35
	speaker = AudioStreamPlayer.new()
	speaker.stream = generator
	add_child(speaker)
	speaker.play()
	playback = speaker.get_stream_playback() as AudioStreamGeneratorPlayback

func receive_pcm(encoded: String) -> void:
	if playback == null:
		return
	var data := Marshalls.base64_to_raw(encoded)
	if data.size() == 0 or data.size() % 2 != 0:
		return
	var frames := data.size() / 2
	if playback.get_frames_available() < frames:
		return # Drop late audio rather than increasing latency.
	for i in range(frames):
		var sample := data[i * 2] | (data[i * 2 + 1] << 8)
		if sample >= 32768:
			sample -= 65536
		var value := float(sample) / 32768.0
		playback.push_frame(Vector2(value, value))

func clear_audio() -> void:
	if playback != null:
		playback.clear_buffer()
