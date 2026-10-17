package com.iroaa15.gaminghub.voice

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import org.godotengine.godot.plugin.SignalInfo
import org.json.JSONObject

/**
 * Development-only Godot 4 Android plugin scaffold.
 *
 * No microphone capture, PeerConnection or audio playback is implemented here.
 * The singleton deliberately refuses to start a call until a verified native
 * WebRTC implementation is installed. Do not distribute as working voice.
 */
class GamingHubVoicePlugin(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName(): String = "GamingHubVoice"

    override fun getPluginSignals(): Set<SignalInfo> =
        setOf(SignalInfo("local_signal", org.godotengine.godot.types.Dictionary::class.java))

    private var active = false

    @UsedByGodot
    fun is_transport_available(): Boolean = false

    @UsedByGodot
    fun has_microphone_permission(): Boolean {
        val activity = activity ?: return false
        return ContextCompat.checkSelfPermission(
            activity, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    @UsedByGodot
    fun receive_signal(json: String) {
        // Validate incoming data even while the transport is unavailable.
        if (!active) return
        val packet = try { JSONObject(json) } catch (_: Exception) { return }
        if (packet.optString("kind") !in setOf("offer", "answer", "ice")) return
        // TODO: forward verified signaling to a real WebRTC PeerConnection.
    }

    @UsedByGodot
    fun stop_call() {
        active = false
        // TODO: close PeerConnection, dispose audio tracks and release mic.
    }

    override fun onMainDestroy() {
        stop_call()
        super.onMainDestroy()
    }
}
