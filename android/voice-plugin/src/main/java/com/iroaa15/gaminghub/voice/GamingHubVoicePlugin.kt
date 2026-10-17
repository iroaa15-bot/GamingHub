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
 * Experimental WebRTC peer integration. The SDP/ICE event bridge is wired
 * in source, but plugin packaging and real-device tests are still missing.
 */
class GamingHubVoicePlugin(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName(): String = "GamingHubVoice"

    override fun getPluginSignals(): Set<SignalInfo> =
        setOf(SignalInfo("local_signal", String::class.java))

    private var active = false
    private var peer: VoicePeer? = null

    @UsedByGodot
    fun is_transport_available(): Boolean = false

    @UsedByGodot
    fun start_call(initiator: Boolean): Boolean {
        if (!has_microphone_permission()) return false
        if (active) return true
        val host = activity ?: return false
        val engine = VoicePeer(host) { packet ->
            // WebRTC callbacks can arrive on a worker thread. Marshal into
            // Godot's main thread before emitting the plugin signal.
            host.runOnUiThread {
                if (active) emitSignal("local_signal", packet.toString())
            }
        }
        if (!engine.start()) return false
        peer = engine
        active = true
        if (initiator) engine.createOffer()
        return true
    }

    @UsedByGodot
    fun set_muted(muted: Boolean) { peer?.mute(muted) }

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
        peer?.receive(packet)
    }

    @UsedByGodot
    fun stop_call() {
        active = false
        peer?.stop()
        peer = null
    }

    override fun onMainDestroy() {
        stop_call()
        super.onMainDestroy()
    }
}
