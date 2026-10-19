package com.gaminghub.voice

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.*
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Process
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Android audio I/O foundation. PCM16 mono, 16 kHz, 20 ms frames (640 bytes).
 * This is NOT a Godot plugin or a completed WebRTC media transport.
 * Callers must obtain RECORD_AUDIO runtime permission before start().
 * Keep capture/playback in the same Android audio session for hardware AEC reference.
 */
class AndroidVoiceEngine(private val context: Context) {
    private val running = AtomicBoolean(false)
    private var recorder: AudioRecord? = null
    private var speaker: AudioTrack? = null
    private var echo: AcousticEchoCanceler? = null
    private var noise: NoiseSuppressor? = null
    private var gain: AutomaticGainControl? = null
    private var captureThread: Thread? = null
    private val frameBytes = 640
    private val rate = 16000
    private val playbackLock = Any()
    private val playbackQueue = ArrayDeque<ByteArray>()
    private val maxBufferedFrames = 10 // 200 ms maximum queue, drop oldest on congestion
    @Volatile var onCapture: ((ByteArray) -> Unit)? = null

    @Suppress("MissingPermission")
    fun start(): Boolean {
        if (running.get()) return true
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return false
        val minRecord = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val minPlay = AudioTrack.getMinBufferSize(rate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minRecord <= 0 || minPlay <= 0) return false
        val record = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION, rate,
            AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minRecord, frameBytes * 4)
        )
        if (record.state != AudioRecord.STATE_INITIALIZED) { record.release(); return false }
        val track = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            .setAudioFormat(AudioFormat.Builder().setSampleRate(rate).setEncoding(AudioFormat.ENCODING_PCM_16BIT).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setBufferSizeInBytes(maxOf(minPlay, frameBytes * 4))
            .setTransferMode(AudioTrack.MODE_STREAM).build()
        if (track.state != AudioTrack.STATE_INITIALIZED) { record.release(); track.release(); return false }
        recorder = record
        speaker = track
        echo = if (AcousticEchoCanceler.isAvailable()) AcousticEchoCanceler.create(record.audioSessionId)?.also { it.enabled = true } else null
        noise = if (NoiseSuppressor.isAvailable()) NoiseSuppressor.create(record.audioSessionId)?.also { it.enabled = true } else null
        gain = if (AutomaticGainControl.isAvailable()) AutomaticGainControl.create(record.audioSessionId)?.also { it.enabled = true } else null
        try {
            record.startRecording()
            track.play()
        } catch (_: IllegalStateException) { stop(); return false }
        running.set(true)
        captureThread = Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
            val frame = ByteArray(frameBytes)
            while (running.get()) {
                var offset = 0
                while (running.get() && offset < frameBytes) {
                    val read = record.read(frame, offset, frameBytes - offset, AudioRecord.READ_BLOCKING)
                    if (read <= 0) { running.set(false); break }
                    offset += read
                }
                if (running.get() && offset == frameBytes) onCapture?.invoke(frame.copyOf())
            }
        }, "GamingHubVoiceCapture").also { it.start() }
        return true
    }

    fun enqueuePlayback(frame: ByteArray) {
        if (!running.get() || frame.size != frameBytes) return
        synchronized(playbackLock) {
            if (playbackQueue.size >= maxBufferedFrames) playbackQueue.removeFirst()
            playbackQueue.addLast(frame.copyOf())
        }
    }

    /** Call on a dedicated playback worker, never the UI thread. */
    fun pumpPlayback() {
        val frame = synchronized(playbackLock) {
            if (playbackQueue.isEmpty()) null else playbackQueue.removeFirst()
        } ?: return
        speaker?.write(frame, 0, frame.size, AudioTrack.WRITE_BLOCKING)
    }

    fun stop() {
        running.set(false)
        try { recorder?.stop() } catch (_: IllegalStateException) {}
        captureThread?.join(500)
        captureThread = null
        echo?.release(); echo = null
        noise?.release(); noise = null
        gain?.release(); gain = null
        recorder?.release(); recorder = null
        try { speaker?.pause(); speaker?.flush(); speaker?.stop() } catch (_: IllegalStateException) {}
        speaker?.release(); speaker = null
        synchronized(playbackLock) { playbackQueue.clear() }
    }
}
