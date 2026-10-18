extends RefCounted
## Experimental consent-gated PCM16 voice transport. 16 kHz mono, 20 ms packets.
## WebSocket relay only: no audio recordings are retained.

const RATE := 16000
const SAMPLES := 320
const MAX_QUEUE_PACKETS := 8
const MAX_PACKETS_PER_POLL := 4
const PLAYBACK_GAIN := 1.2
const TARGET_PEAK := 0.65
const MAX_AUTO_GAIN := 3.0
const NOISE_GATE := 0.012
var _source_rate := 48000.0
var _smoothed_gain := 1.0
var _phase := 0.0
var _samples := PackedFloat32Array()
var _out: AudioStreamPlayer
var _stream: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _received: Array[PackedVector2Array] = []
var dropped_packets := 0

func start(parent: Node) -> void:
 stop()
 if parent == null:
  return
 _source_rate = float(AudioServer.get_mix_rate())
 if _source_rate <= 0.0:
  _source_rate = 48000.0
 _stream = AudioStreamGenerator.new()
 _stream.mix_rate = RATE
 _stream.buffer_length = 0.3
 _out = AudioStreamPlayer.new()
 _out.stream = _stream
 _out.bus = "Master"
 parent.add_child(_out)
 _out.play()
 _playback = _out.get_stream_playback() as AudioStreamGeneratorPlayback

func stop() -> void:
 if is_instance_valid(_out):
  _out.stop()
  _out.queue_free()
 _out = null
 _playback = null
 _stream = null
 _received.clear()
 dropped_packets = 0
 _samples.clear()
 _phase = 0.0
 _smoothed_gain = 1.0

func encode_frames(frames: PackedVector2Array) -> Array[String]:
 var packets: Array[String] = []
 var stride := _source_rate / float(RATE)
 for frame in frames:
  _phase += 1.0
  if _phase < stride:
   continue
  _phase -= stride
  var sample := clampf((frame.x + frame.y) * 0.5, -1.0, 1.0)
  _samples.append(sample)
  if _samples.size() == SAMPLES:
   var peak := 0.0
   for peak_sample in _samples:
    peak = maxf(peak, absf(peak_sample))
   var target_gain: float = 1.0
   if peak >= NOISE_GATE:
    target_gain = clampf(TARGET_PEAK / maxf(peak, 0.001), 1.0, MAX_AUTO_GAIN)
   _smoothed_gain = lerpf(_smoothed_gain, target_gain, 0.15)
   var pcm := PackedByteArray()
   pcm.resize(SAMPLES * 2)
   for i in range(SAMPLES):
    var pcm_sample: float = _samples[i]
    if absf(pcm_sample) < NOISE_GATE:
     pcm_sample *= 0.15
    var value := clampi(int(round(clampf(pcm_sample * _smoothed_gain, -0.95, 0.95) * 32767.0)), -32768, 32767)
    pcm[i * 2] = value & 255
    pcm[i * 2 + 1] = (value >> 8) & 255
   packets.append(Marshalls.raw_to_base64(pcm))
   _samples.clear()
 return packets

func receive_packet(encoded: String) -> bool:
 if _playback == null or encoded.length() != 856:
  return false
 var pcm := Marshalls.base64_to_raw(encoded)
 if pcm.size() != SAMPLES * 2:
  return false
 var frames := PackedVector2Array()
 frames.resize(SAMPLES)
 for i in range(SAMPLES):
  var value := int(pcm[i * 2]) | (int(pcm[i * 2 + 1]) << 8)
  if value >= 32768:
   value -= 65536
  var amplitude := clampf(float(value) / 32768.0 * PLAYBACK_GAIN, -1.0, 1.0)
  frames[i] = Vector2(amplitude, amplitude)
 if _received.size() >= MAX_QUEUE_PACKETS:
  _received.pop_front()
  dropped_packets += 1
 _received.append(frames)
 return true

func pump() -> void:
 if _playback == null:
  return
 var sent := 0
 while not _received.is_empty() and _playback.get_frames_available() >= SAMPLES and sent < MAX_PACKETS_PER_POLL:
  _playback.push_buffer(_received.pop_front())
  sent += 1
