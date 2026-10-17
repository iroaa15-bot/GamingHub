package com.iroaa15.gaminghub.voice

import android.content.Context
import org.json.JSONObject
import org.webrtc.AudioSource
import org.webrtc.AudioTrack
import org.webrtc.DefaultVideoDecoderFactory
import org.webrtc.DefaultVideoEncoderFactory
import org.webrtc.IceCandidate
import org.webrtc.MediaConstraints
import org.webrtc.MediaStream
import org.webrtc.PeerConnection
import org.webrtc.PeerConnectionFactory
import org.webrtc.RtpReceiver
import org.webrtc.SdpObserver
import org.webrtc.SessionDescription

/**
 * Android WebRTC audio engine. Must be bundled with a compatible org.webrtc
 * Android artifact; not wired into the Godot export yet.
 *
 * Every callback is delivered through [emit]. The caller is responsible for
 * authenticated room signaling and mutual consent.
 */
internal class VoicePeer(
    private val context: Context,
    private val emit: (JSONObject) -> Unit
) {
    private var factory: PeerConnectionFactory? = null
    private var peer: PeerConnection? = null
    private var source: AudioSource? = null
    private var track: AudioTrack? = null

    fun start(stunUrl: String = "stun:stun.l.google.com:19302"): Boolean {
        if (peer != null) return true
        PeerConnectionFactory.initialize(
            PeerConnectionFactory.InitializationOptions.builder(context).createInitializationOptions()
        )
        val f = PeerConnectionFactory.builder().createPeerConnectionFactory()
        factory = f
        val config = PeerConnection.RTCConfiguration(
            listOf(PeerConnection.IceServer.builder(stunUrl).createIceServer())
        )
        val connection = f.createPeerConnection(config, object : PeerConnection.Observer {
            override fun onSignalingChange(state: PeerConnection.SignalingState?) {}
            override fun onIceConnectionChange(state: PeerConnection.IceConnectionState?) {}
            override fun onIceConnectionReceivingChange(receiving: Boolean) {}
            override fun onIceGatheringChange(state: PeerConnection.IceGatheringState?) {}
            override fun onIceCandidate(candidate: IceCandidate?) {
                if (candidate == null) return
                emit(JSONObject().put("kind", "ice").put("candidate", candidate.sdp)
                    .put("sdpMid", candidate.sdpMid)
                    .put("sdpMLineIndex", candidate.sdpMLineIndex))
            }
            override fun onIceCandidatesRemoved(candidates: Array<out IceCandidate>?) {}
            override fun onAddStream(stream: MediaStream?) {}
            override fun onRemoveStream(stream: MediaStream?) {}
            override fun onDataChannel(channel: org.webrtc.DataChannel?) {}
            override fun onRenegotiationNeeded() {}
            override fun onAddTrack(receiver: RtpReceiver?, streams: Array<out MediaStream>?) {}
        }) ?: run { f.dispose(); factory = null; return false }
        peer = connection
        val audioSource = f.createAudioSource(MediaConstraints())
        source = audioSource
        val audioTrack = f.createAudioTrack("gaminghub_audio", audioSource)
        track = audioTrack
        connection.addTrack(audioTrack, listOf("gaminghub_voice"))
        return true
    }

    fun createOffer() {
        peer?.createOffer(observer { description ->
            peer?.setLocalDescription(observer(), description)
            emit(JSONObject().put("kind", "offer").put("sdp", description.description))
        }, MediaConstraints())
    }

    fun receive(message: JSONObject) {
        val connection = peer ?: return
        when (message.optString("kind")) {
            "offer", "answer" -> {
                val kind = if (message.optString("kind") == "offer")
                    SessionDescription.Type.OFFER else SessionDescription.Type.ANSWER
                val sdp = message.optString("sdp")
                if (sdp.isBlank()) return
                connection.setRemoteDescription(observer {
                    if (kind == SessionDescription.Type.OFFER) {
                        connection.createAnswer(observer { answer ->
                            connection.setLocalDescription(observer(), answer)
                            emit(JSONObject().put("kind", "answer").put("sdp", answer.description))
                        }, MediaConstraints())
                    }
                }, SessionDescription(kind, sdp))
            }
            "ice" -> {
                val candidate = message.optString("candidate")
                if (candidate.isNotBlank()) {
                    connection.addIceCandidate(IceCandidate(
                        message.optString("sdpMid"),
                        message.optInt("sdpMLineIndex", 0),
                        candidate
                    ))
                }
            }
        }
    }

    fun mute(muted: Boolean) { track?.setEnabled(!muted) }

    fun stop() {
        track?.setEnabled(false)
        peer?.close()
        peer?.dispose()
        peer = null
        track?.dispose()
        track = null
        source?.dispose()
        source = null
        factory?.dispose()
        factory = null
    }

    private fun observer(onSuccess: (SessionDescription) -> Unit = {}) = object : SdpObserver {
        override fun onCreateSuccess(sdp: SessionDescription?) { if (sdp != null) onSuccess(sdp) }
        override fun onSetSuccess() {}
        override fun onCreateFailure(error: String?) {}
        override fun onSetFailure(error: String?) {}
    }
}
