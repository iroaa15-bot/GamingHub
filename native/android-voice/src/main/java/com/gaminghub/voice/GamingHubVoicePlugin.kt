package com.gaminghub.voice

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioManager
import android.util.Base64
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import org.godotengine.godot.plugin.SignalInfo
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/** Godot v2 plugin. Bounded polling avoids 50 UI/render Runnables per second. */
class GamingHubVoicePlugin(godot: Godot) : GodotPlugin(godot) {
    private val control = Executors.newSingleThreadScheduledExecutor { task -> Thread(task, "GHVoiceControl") }
    private val generation = AtomicInteger(0)
    private val captured = CapturedFrames()
    @Volatile private var engine: AndroidVoiceEngine? = null
    @Volatile private var rtcEngine: WebRtcVoiceEngine? = null
    @Volatile private var foreground = true
    @Volatile private var destroyed = false
    @Volatile private var active = false
    private var permissionPending = false
    private var previousVolumeStream: Int? = null
    override fun getPluginName() = "GamingHubVoice"
    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("microphone_permission", Boolean::class.javaObjectType),
        SignalInfo("voice_signal", String::class.java, String::class.java, Int::class.javaObjectType),
        SignalInfo("voice_status", String::class.java, Int::class.javaObjectType, String::class.java))

    @UsedByGodot fun getVoiceApiVersion(): Int = 2
    @UsedByGodot fun supportsWebRtcVoice(): Boolean = true
    @UsedByGodot fun startWebRtcVoice(requestId: Int, caller: Boolean, iceJson: String): Boolean {
        val host = activity ?: return false
        if (destroyed || !foreground || !hasMicrophonePermission() || iceJson.length > 8192) return false
        val ticket = generation.incrementAndGet()
        active = false; captured.clear()
        control.execute {
            engine?.stop(); engine = null; rtcEngine?.stop(); rtcEngine = null
            if (destroyed || !foreground || generation.get() != ticket) return@execute
            val instance = WebRtcVoiceEngine(host.applicationContext, control, caller,
                { kind, payload -> if (!destroyed && generation.get() == ticket)
                    emitSignal("voice_signal", kind, payload, requestId) },
                { state, details -> if (!destroyed && generation.get() == ticket) {
                    active = state == "started"
                    if (active) host.runOnUiThread {
                        if (generation.get() == ticket && !destroyed) {
                            if (previousVolumeStream == null) previousVolumeStream = host.volumeControlStream
                            host.volumeControlStream = AudioManager.STREAM_VOICE_CALL
                        }
                    }
                    emitSignal("voice_status", state, requestId, details)
                } },
                { reason -> if (generation.compareAndSet(ticket, ticket + 1)) {
                    active = false; restoreVolumeKeys()
                    val failedEngine = rtcEngine
                    control.execute { if (rtcEngine === failedEngine) { failedEngine?.stop(); rtcEngine = null } }
                    if (!destroyed) emitSignal("voice_status", "error", requestId, reason)
                } })
            rtcEngine = instance
            try {
                android.util.Log.i("GamingHubVoice", "WebRTC start requested; ticket=$ticket")
                instance.start(iceJson)
            } catch (error: Throwable) {
                // A missing/incompatible native WebRTC symbol can throw LinkageError
                // (not Exception). Never let the dedicated control thread die silently.
                val reason = if (error is LinkageError) "webrtc_library_unavailable"
                             else "webrtc_start_failed"
                android.util.Log.e("GamingHubVoice", "WebRTC start failed ($reason)", error)
                if (generation.compareAndSet(ticket, ticket + 1)) {
                    try { instance.stop() } catch (cleanup: Throwable) {
                        android.util.Log.e("GamingHubVoice", "WebRTC cleanup failed", cleanup)
                    }
                    if (rtcEngine === instance) rtcEngine = null
                    emitSignal("voice_status", "error", requestId, reason)
                }
            }
        }
        return true
    }
    @UsedByGodot fun receiveWebRtcSignal(kind: String, payload: String, requestId: Int) {
        if (destroyed || payload.length > 18000 || kind !in listOf("voice_offer", "voice_answer", "voice_ice")) return
        val ticket = generation.get()
        control.execute {
            if (generation.get() == ticket && !destroyed) try { rtcEngine?.receive(kind, payload) }
            catch (_: Exception) { emitSignal("voice_status", "error", requestId, "webrtc_signal_failed") }
        }
    }
    @UsedByGodot fun hasMicrophonePermission(): Boolean =
        activity?.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    @UsedByGodot fun requestMicrophonePermission() {
        val host = activity ?: return
        host.runOnUiThread {
            if (hasMicrophonePermission()) emitSignal("microphone_permission", true)
            else if (!permissionPending && !destroyed) {
                permissionPending = true
                host.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 7821)
            }
        }
    }
    override fun onMainRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (requestCode == 7821) {
            permissionPending = false
            emitSignal("microphone_permission", hasMicrophonePermission())
        }
    }
    @UsedByGodot fun startVoice(requestId: Int): Boolean {
        val host = activity ?: return false
        if (destroyed || !foreground || !hasMicrophonePermission()) return false
        val ticket = generation.incrementAndGet()
        active = false
        captured.clear()
        control.execute {
            engine?.stop(); engine = null; rtcEngine?.stop(); rtcEngine = null
            captured.clear() // The previous capture worker is now joined.
            if (destroyed || !foreground || generation.get() != ticket) return@execute
            val instance = AndroidVoiceEngine(host.applicationContext)
            engine = instance
            instance.onCapture = { frame ->
                if (active && generation.get() == ticket) captured.offer(frame, System.nanoTime())
            }
            instance.onFailure = { reason ->
                if (generation.compareAndSet(ticket, ticket + 1)) {
                    active = false; captured.clear()
                    restoreVolumeKeys()
                    // Engine failure can originate on an audio worker; cleanup stays serialized.
                    control.execute {
                        if (engine === instance) { instance.stop(); engine = null }
                        if (!destroyed) emitSignal("voice_status", "error", requestId, reason)
                    }
                }
            }
            if (instance.start()) {
                if (generation.get() == ticket && foreground && !destroyed) {
                    active = true
                    host.runOnUiThread {
                        if (active && generation.get() == ticket) {
                            if (previousVolumeStream == null) previousVolumeStream = host.volumeControlStream
                            host.volumeControlStream = AudioManager.STREAM_VOICE_CALL
                        }
                    }
                    emitSignal("voice_status", "started", requestId, instance.diagnostics())
                } else { instance.stop(); if (engine === instance) engine = null }
            } else if (generation.compareAndSet(ticket, ticket + 1)) {
                instance.stop(); engine = null
                emitSignal("voice_status", "error", requestId, "audio_start_failed")
            }
        }
        return true
    }
    @UsedByGodot fun drainCapturedFrames(): Array<String> {
        if (!active) return emptyArray()
        return captured.drain(System.nanoTime()).map { Base64.encodeToString(it, Base64.NO_WRAP) }.toTypedArray()
    }
    @UsedByGodot fun playVoiceFrame(base64Pcm: String, sequence: Int): Boolean {
        if (!active || base64Pcm.length != 856) return false
        val frame = try { Base64.decode(base64Pcm, Base64.NO_WRAP) } catch (_: IllegalArgumentException) { return false }
        return engine?.enqueuePlayback(frame, sequence) == true
    }
    @UsedByGodot fun stopVoice() = stopSession(false)
    private fun stopSession(suspended: Boolean) {
        if (destroyed) return
        generation.incrementAndGet()
        active = false
        captured.clear()
        restoreVolumeKeys()
        control.execute { engine?.stop(); engine = null; rtcEngine?.stop(); rtcEngine = null; captured.clear() }
        if (suspended) emitSignal("voice_status", "suspended", -1, "audio_session_interrupted")
    }
    private fun restoreVolumeKeys() {
        val host = activity ?: return
        host.runOnUiThread {
            previousVolumeStream?.let { host.volumeControlStream = it }
            previousVolumeStream = null
        }
    }
    override fun onMainPause() { foreground = false; stopSession(true) }
    override fun onMainResume() { foreground = true }
    override fun onMainDestroy() {
        generation.incrementAndGet()
        active = false; destroyed = true; captured.clear()
        restoreVolumeKeys()
        control.execute { engine?.stop(); engine = null; rtcEngine?.stop(); rtcEngine = null; captured.clear() }
        control.shutdown()
        super.onMainDestroy()
    }
}
