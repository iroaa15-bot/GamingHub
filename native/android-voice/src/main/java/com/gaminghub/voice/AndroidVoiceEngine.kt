package com.gaminghub.voice

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.*
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AudioEffect
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.LockSupport

/** One communication session. Control operations run on the plugin's serial executor. */
class AndroidVoiceEngine(private val context: Context) {
    companion object {
        const val RATE = 16000
        const val FRAME_BYTES = 640 // PCM16 LE, mono, 20 ms
        private const val FRAME_NS = 20_000_000L
    }
    private val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val running = AtomicBoolean(false)
    private val failed = AtomicBoolean(false)
    private val jitter = VoiceJitterBuffer()
    private var record: AudioRecord? = null
    private var track: AudioTrack? = null
    private var capture: Thread? = null
    private var playback: Thread? = null
    private var echo: AcousticEchoCanceler? = null
    private var noise: NoiseSuppressor? = null
    private var gain: AutomaticGainControl? = null
    private var previousMode = AudioManager.MODE_NORMAL
    private var previousSpeaker = false
    private var ownsRoute = false
    private var ownsFocus = false
    private var focusRequest: AudioFocusRequest? = null
    @Volatile var onCapture: ((ByteArray) -> Unit)? = null
    @Volatile var onFailure: ((String) -> Unit)? = null
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0 && running.get()) fail("audio_focus_lost")
    }
    private val devices = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>) = routeChanged()
        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) = routeChanged()
    }

    @Suppress("MissingPermission", "DEPRECATION")
    fun start(): Boolean {
        if (running.get()) return true
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return false
        failed.set(false)
        try {
            previousMode = manager.mode
            previousSpeaker = manager.isSpeakerphoneOn
            ownsRoute = true
            manager.mode = AudioManager.MODE_IN_COMMUNICATION
            val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
            val focus = if (Build.VERSION.SDK_INT >= 26) {
                focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener,
                        Handler(Looper.getMainLooper())).build()
                manager.requestAudioFocus(focusRequest!!)
            } else manager.requestAudioFocus(focusListener, AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            ownsFocus = focus == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            check(ownsFocus) { "audio_focus_denied" }
            selectRoute()
            val minRecord = AudioRecord.getMinBufferSize(RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            val minPlay = AudioTrack.getMinBufferSize(RATE, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
            check(minRecord > 0 && minPlay > 0) { "unsupported_audio_format" }
            record = AudioRecord(MediaRecorder.AudioSource.VOICE_COMMUNICATION, RATE,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(minRecord, FRAME_BYTES * 3))
            val recorder = record!!
            check(recorder.state == AudioRecord.STATE_INITIALIZED) { "recorder_init_failed" }
            track = AudioTrack.Builder().setAudioAttributes(attributes)
                .setAudioFormat(AudioFormat.Builder().setSampleRate(RATE).setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                .setBufferSizeInBytes(maxOf(minPlay, FRAME_BYTES * 3)).setTransferMode(AudioTrack.MODE_STREAM).build()
            val speaker = track!!
            check(speaker.state == AudioTrack.STATE_INITIALIZED) { "playback_init_failed" }
            speaker.setVolume(1.0f) // Respect the user's communication volume.
            // Capture effects attach to AudioRecord's session. AEC's playback reference
            // comes from the communication route/HAL, not a shared AudioTrack session ID.
            echo = enableEffect { if (AcousticEchoCanceler.isAvailable()) AcousticEchoCanceler.create(recorder.audioSessionId) else null }
            noise = enableEffect { if (NoiseSuppressor.isAvailable()) NoiseSuppressor.create(recorder.audioSessionId) else null }
            gain = enableEffect { if (AutomaticGainControl.isAvailable()) AutomaticGainControl.create(recorder.audioSessionId) else null }
            jitter.clear()
            recorder.startRecording()
            check(recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING) { "recording_not_started" }
            speaker.play()
            running.set(true)
            manager.registerAudioDeviceCallback(devices, Handler(Looper.getMainLooper()))
            capture = Thread({ audioWorker {
                val normalizer = Pcm16Normalizer()
                val frame = ByteArray(FRAME_BYTES)
                while (running.get()) {
                    var offset = 0
                    while (running.get() && offset < frame.size) {
                        val read = recorder.read(frame, offset, frame.size - offset, AudioRecord.READ_BLOCKING)
                        check(read > 0) { "record_read_$read" }
                        offset += read
                    }
                    if (running.get()) {
                        if (gain == null) normalizer.process(frame)
                        onCapture?.invoke(frame.copyOf())
                    }
                }
            } }, "GHVoiceCapture").also { it.start() }
            playback = Thread({ audioWorker {
                var deadline = System.nanoTime()
                val silence = ByteArray(FRAME_BYTES)
                while (running.get()) {
                    val frame = jitter.poll(System.nanoTime()) ?: silence
                    var offset = 0
                    while (running.get() && offset < frame.size) {
                        val written = speaker.write(frame, offset, frame.size - offset, AudioTrack.WRITE_BLOCKING)
                        check(written > 0) { "playback_write_$written" }
                        offset += written
                    }
                    deadline += FRAME_NS
                    if (deadline < System.nanoTime() - FRAME_NS) deadline = System.nanoTime()
                    while (running.get() && System.nanoTime() < deadline) {
                        LockSupport.parkNanos(deadline - System.nanoTime())
                    }
                }
            } }, "GHVoicePlayback").also { it.start() }
            return true
        } catch (error: Exception) {
            stop()
            onFailure?.invoke(error.message ?: "audio_start_failed")
            return false
        }
    }
    private inline fun <T : AudioEffect> enableEffect(create: () -> T?): T? {
        var effect: T? = null
        return try {
            effect = create()
            if (effect != null && effect.setEnabled(true) == AudioEffect.SUCCESS && effect.enabled) effect
            else { effect?.release(); null }
        } catch (_: RuntimeException) { effect?.release(); null }
    }
    @Suppress("DEPRECATION")
    @Synchronized private fun selectRoute() {
        if (!ownsRoute) return
        val wiredTypes = mutableSetOf(AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_USB_DEVICE)
        if (Build.VERSION.SDK_INT >= 26) wiredTypes.add(AudioDeviceInfo.TYPE_USB_HEADSET)
        if (Build.VERSION.SDK_INT >= 31) {
            val available = manager.availableCommunicationDevices
            val device = available.firstOrNull { it.type in wiredTypes }
                ?: available.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            check(device != null && manager.setCommunicationDevice(device)) { "communication_route_failed" }
        } else {
            manager.isSpeakerphoneOn = !manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { it.type in wiredTypes }
        }
    }
    private fun routeChanged() {
        if (running.get()) try { selectRoute() } catch (_: RuntimeException) { fail("audio_route_lost") }
    }
    private inline fun audioWorker(block: () -> Unit) {
        try { Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO); block() }
        catch (error: Exception) { if (running.get()) fail(error.message ?: "audio_worker_failed") }
    }
    private fun fail(reason: String) {
        if (failed.compareAndSet(false, true)) {
            running.set(false)
            onFailure?.invoke(reason) // Cleanup on control executor, never join this worker.
        }
    }
    fun enqueuePlayback(frame: ByteArray, sequence: Int): Boolean =
        running.get() && jitter.offer(frame, sequence, System.nanoTime())
    fun diagnostics(): String = JSONObject().put("sample_rate", RATE).put("frame_ms", 20)
        .put("aec", echo?.enabled == true).put("ns", noise?.enabled == true).put("agc", gain?.enabled == true)
        .put("software_gain", gain == null).put("mode", manager.mode)
        .put("capture_device", record?.routedDevice?.type ?: -1)
        .put("playback_device", track?.routedDevice?.type ?: -1).toString()

    @Suppress("DEPRECATION")
    fun stop() {
        running.set(false)
        if (ownsRoute) manager.unregisterAudioDeviceCallback(devices)
        // Unblock both native I/O calls before joining/releasing their objects.
        try { record?.stop() } catch (_: RuntimeException) {}
        try { track?.pause(); track?.flush() } catch (_: RuntimeException) {}
        capture?.interrupt(); playback?.interrupt()
        capture?.join(1000); playback?.join(1000)
        capture = null; playback = null
        echo?.release(); echo = null
        noise?.release(); noise = null
        gain?.release(); gain = null
        record?.release(); record = null
        try { track?.stop() } catch (_: RuntimeException) {}
        track?.release(); track = null
        jitter.clear()
        synchronized(this) {
            if (ownsRoute) {
                if (Build.VERSION.SDK_INT >= 31) manager.clearCommunicationDevice()
                else manager.isSpeakerphoneOn = previousSpeaker
                manager.mode = previousMode
                ownsRoute = false
            }
        }
        if (ownsFocus) {
            if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { manager.abandonAudioFocusRequest(it) }
            else manager.abandonAudioFocus(focusListener)
            ownsFocus = false
        }
        focusRequest = null
    }
}
