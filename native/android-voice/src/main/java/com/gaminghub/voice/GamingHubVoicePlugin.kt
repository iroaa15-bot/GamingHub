package com.gaminghub.voice

import android.Manifest
import android.content.pm.PackageManager
import android.util.Base64
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import org.godotengine.godot.plugin.SignalInfo
import android.os.Build

/**
 * Godot 4 Android plugin interface for the PCM voice engine.
 * Build and package as an Android plugin AAR; not a standalone Godot script.
 * Voice transport remains the responsibility of the game.
 */
class GamingHubVoicePlugin(godot: Godot) : GodotPlugin(godot) {
    private var engine: AndroidVoiceEngine? = null
    override fun getPluginName() = "GamingHubVoice"

    override fun getPluginSignals(): Set<SignalInfo> =
        setOf(SignalInfo("voice_frame", String::class.java))

    @UsedByGodot
    fun hasMicrophonePermission(): Boolean {
        val activity = activity ?: return false
        return activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    @UsedByGodot
    fun requestMicrophonePermission() {
        val host = activity ?: return
        if (!hasMicrophonePermission() && Build.VERSION.SDK_INT >= 23) {
            host.runOnUiThread {
                host.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 7821)
            }
        }
    }

    @UsedByGodot
    fun startVoice(): Boolean {
        val activity = activity ?: return false
        if (!hasMicrophonePermission()) return false
        if (engine == null) engine = AndroidVoiceEngine(activity.applicationContext)
        val instance = engine ?: return false
        instance.onCapture = { frame ->
            // Godot signals cross to its main thread via the activity UI thread.
            activity.runOnUiThread {
                emitSignal("voice_frame", Base64.encodeToString(frame, Base64.NO_WRAP))
            }
        }
        return instance.start()
    }

    @UsedByGodot
    fun playVoiceFrame(base64Pcm: String): Boolean {
        val frame = try { Base64.decode(base64Pcm, Base64.NO_WRAP) }
                    catch (_: IllegalArgumentException) { return false }
        if (frame.size != 640) return false
        val instance = engine ?: return false
        instance.enqueuePlayback(frame)
        return true
    }

    @UsedByGodot
    fun stopVoice() {
        engine?.stop()
        engine = null
    }

    override fun onMainDestroy() {
        stopVoice()
        super.onMainDestroy()
    }
}
