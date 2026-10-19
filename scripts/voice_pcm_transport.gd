extends RefCounted
## Experimental consent-gated PCM16 voice transport. 16 kHz mono, 20 ms packets.
## WebSocket relay only: no audio recordings are retained.

const RATE := 16000
const SAMPLES := 320
const MAX_QUEUE_PACKETS := 12
const JITTER_START_PACKETS := 3
const JITTER_RECOVERY_PACKETS := 4
const PLAYBACK_LOW_WATER_FRAMES := SAMPLES
const MAX_PACKETS_PER_POLL := 4
const PLAYBACK_GAIN := 1.2
const TARGET_PEAK := 0.65
const MAX_AUTO_GAIN := 3.0
const NOISE_GATE := 0.012
var _source_rate := 48000.0
var _smoothed_gain := 1.0
## Local loopback diagnostic only: suppress background hiss while the mic is idle.
var suppress_silence := false
const LOCAL_SILENCE_PEAK := 0.025
var _phase := 0.0
var _samples := PackedFloat32Array()
var _out: AudioStreamPlayer
var _stream: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _received: Array[PackedVector2Array] = []
var dropped_packets := 0
var received_packets := 0
var jitter_rebuffers := 0
var _jitter_primed := false
var _playback_started := false

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
 received_packets = 0
 jitter_rebuffers = 0
 _jitter_primed = false
 _playback_started = false
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
   var quiet_local_packet := suppress_silence and peak < LOCAL_SILENCE_PEAK
   if peak >= NOISE_GATE and not quiet_local_packet:
    target_gain = clampf(TARGET_PEAK / maxf(peak, 0.001), 1.0, MAX_AUTO_GAIN)
   _smoothed_gain = lerpf(_smoothed_gain, target_gain, 0.15)
   var pcm := PackedByteArray()
   pcm.resize(SAMPLES * 2)
   for i in range(SAMPLES):
    var pcm_sample: float = 0.0 if quiet_local_packet else _samples[i]
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
 received_packets += 1
 return true

func pump() -> void:
 if _playback == null:
  return
 # Do not start playback from a single network packet: wait for ~60ms
 # of audio to absorb ordinary WebSocket/mobile scheduling jitter.
 if not _jitter_primed:
  var required_packets := JITTER_RECOVERY_PACKETS if _playback_started else JITTER_START_PACKETS
  if _received.size() < required_packets:
   return
  _jitter_primed = true
  _playback_started = true
 var sent := 0
 while not _received.is_empty() and _playback.get_frames_available() >= SAMPLES and sent < MAX_PACKETS_PER_POLL:
  _playback.push_buffer(_received.pop_front())
  sent += 1
 # Rebuild a small reserve after a network stall instead of repeatedly
 # playing isolated 20ms fragments separated by audible gaps.
 # Only rebuffer once the generator itself is almost empty. An empty
 # network queue is normal between packets and must NOT restart the jitter
 # prebuffer on every 20ms packet (which caused repeated speech dropouts).
 var generator_capacity := int(_stream.buffer_length * float(RATE))
 var buffered_frames := maxi(0, generator_capacity - _playback.get_frames_available())
 if _received.is_empty() and buffered_frames < SAMPLES:
  if _jitter_primed:
   jitter_rebuffers += 1
  _jitter_primed = false
