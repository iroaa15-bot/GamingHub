package com.gaminghub.voice

import android.content.Context
import android.media.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import org.webrtc.*
import org.webrtc.audio.JavaAudioDeviceModule
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/** Audio-only libwebrtc. Control and disposal are serialized away from Godot's render thread. */
class WebRtcVoiceEngine(private val context: Context, private val control: ScheduledExecutorService,
    private val caller: Boolean, private val signal: (String, String) -> Unit,
    private val status: (String, String) -> Unit, private val failure: (String) -> Unit) {
    companion object {
        private var initialized = false
        @Synchronized private fun initialize(context: Context) {
            if (!initialized) {
                PeerConnectionFactory.initialize(PeerConnectionFactory.InitializationOptions.builder(context)
                    .setEnableInternalTracer(false).createInitializationOptions())
                initialized = true
            }
        }
    }
    private val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private var factory: PeerConnectionFactory? = null
    private var adm: JavaAudioDeviceModule? = null
    private var peer: PeerConnection? = null
    private var source: AudioSource? = null
    private var local: org.webrtc.AudioTrack? = null
    private val candidates = ArrayDeque<IceCandidate>()
    private var closed = false
    private var failed = false
    private var previousMode = AudioManager.MODE_NORMAL
    private var previousSpeaker = false
    private var previousDevice: AudioDeviceInfo? = null
    private var ownsRoute = false
    private var ownsFocus = false
    private var focus: AudioFocusRequest? = null
    private var retry: ScheduledFuture<*>? = null
    private var attempts = 0
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) dispatch { fail("audio_focus_lost") }
    }
    private val devices = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>) = dispatch { route() }
        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) = dispatch { route() }
    }
    private fun dispatch(block: () -> Unit) {
        if (!control.isShutdown) control.execute {
            if (!closed) try { block() } catch (_: Exception) { fail("webrtc_operation_failed") }
        }
    }
    private fun fail(reason: String) {
        if (!failed && !closed) { failed = true; failure(reason) }
    }
    @Suppress("DEPRECATION")
    fun start(iceJson: String) {
        initialize(context)
        previousMode = manager.mode; previousSpeaker = manager.isSpeakerphoneOn
        if (Build.VERSION.SDK_INT >= 31) previousDevice = manager.communicationDevice
        ownsRoute = true
        manager.mode = AudioManager.MODE_IN_COMMUNICATION
        val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build()
        val grant = if (Build.VERSION.SDK_INT >= 26) {
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener, handler).build()
            manager.requestAudioFocus(focus!!)
        } else manager.requestAudioFocus(focusListener, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        ownsFocus = grant == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        check(ownsFocus) { "audio_focus_denied" }
        route()
        manager.registerAudioDeviceCallback(devices, handler)
        adm = JavaAudioDeviceModule.builder(context)
            .setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION).setAudioAttributes(attributes)
            // WebRTC owns capture AND the render reference, resampling and delay estimation.
            // Use its software AEC/NS rather than assume consistent OEM effects.
            .setUseHardwareAcousticEchoCanceler(false).setUseHardwareNoiseSuppressor(false)
            .setUseStereoInput(false).setUseStereoOutput(false).setEnableVolumeLogger(false)
            .setAudioRecordErrorCallback(object : JavaAudioDeviceModule.AudioRecordErrorCallback {
                override fun onWebRtcAudioRecordInitError(message: String) = dispatch { fail("record_init_failed") }
                override fun onWebRtcAudioRecordStartError(code: JavaAudioDeviceModule.AudioRecordStartErrorCode, message: String) = dispatch { fail("record_start_failed") }
                override fun onWebRtcAudioRecordError(message: String) = dispatch { fail("record_io_failed") }
            }).setAudioTrackErrorCallback(object : JavaAudioDeviceModule.AudioTrackErrorCallback {
                override fun onWebRtcAudioTrackInitError(message: String) = dispatch { fail("playback_init_failed") }
                override fun onWebRtcAudioTrackStartError(code: JavaAudioDeviceModule.AudioTrackStartErrorCode, message: String) = dispatch { fail("playback_start_failed") }
                override fun onWebRtcAudioTrackError(message: String) = dispatch { fail("playback_io_failed") }
            }).createAudioDeviceModule()
        factory = PeerConnectionFactory.builder().setAudioDeviceModule(adm).createPeerConnectionFactory()
        val ice = mutableListOf(PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer())
        val turn = JSONObject(iceJson)
        val urls = turn.optJSONArray("urls")
        if (urls != null && urls.length() <= 8) {
            val allowed = (0 until urls.length()).map { urls.getString(it) }.filter { it.startsWith("turn:") || it.startsWith("turns:") }
            if (allowed.isNotEmpty()) ice.add(PeerConnection.IceServer.builder(allowed)
                .setUsername(turn.optString("username")).setPassword(turn.optString("credential")).createIceServer())
        }
        val config = PeerConnection.RTCConfiguration(ice).apply {
            sdpSemantics = PeerConnection.SdpSemantics.UNIFIED_PLAN
            bundlePolicy = PeerConnection.BundlePolicy.MAXBUNDLE
            rtcpMuxPolicy = PeerConnection.RtcpMuxPolicy.REQUIRE
            continualGatheringPolicy = PeerConnection.ContinualGatheringPolicy.GATHER_CONTINUALLY
        }
        peer = factory!!.createPeerConnection(config, object : PeerConnection.Observer {
            override fun onSignalingChange(state: PeerConnection.SignalingState) {}
            override fun onIceConnectionChange(state: PeerConnection.IceConnectionState) {}
            override fun onConnectionChange(state: PeerConnection.PeerConnectionState) = dispatch {
                when (state) {
                    PeerConnection.PeerConnectionState.CONNECTED -> {
                        retry?.cancel(false); retry = null; attempts = 0
                        status("started", JSONObject().put("engine", "libwebrtc-144.7559.15")
                            .put("aec", "webrtc_software").put("ns", "webrtc_software")
                            .put("agc", "webrtc").put("codec", "opus").put("mode", manager.mode).toString())
                    }
                    PeerConnection.PeerConnectionState.DISCONNECTED, PeerConnection.PeerConnectionState.FAILED -> reconnect()
                    else -> {}
                }
            }
            override fun onIceConnectionReceivingChange(receiving: Boolean) {}
            override fun onIceGatheringChange(state: PeerConnection.IceGatheringState) {}
            override fun onIceCandidate(candidate: IceCandidate) = dispatch {
                signal("voice_ice", JSONObject().put("candidate", candidate.sdp)
                    .put("sdpMid", candidate.sdpMid).put("sdpMLineIndex", candidate.sdpMLineIndex).toString())
            }
            override fun onIceCandidatesRemoved(candidates: Array<out IceCandidate>) {}
            override fun onAddStream(stream: MediaStream) {}
            override fun onRemoveStream(stream: MediaStream) {}
            override fun onDataChannel(channel: DataChannel) { channel.close() }
            override fun onRenegotiationNeeded() {}
            override fun onTrack(transceiver: RtpTransceiver) = dispatch {
                (transceiver.receiver.track() as? org.webrtc.AudioTrack)?.apply { setEnabled(true); setVolume(1.0) }
            }
        }) ?: error("webrtc_peer_init_failed")
        source = factory!!.createAudioSource(MediaConstraints().apply {
            optional.add(MediaConstraints.KeyValuePair("googEchoCancellation", "true"))
            optional.add(MediaConstraints.KeyValuePair("googNoiseSuppression", "true"))
            optional.add(MediaConstraints.KeyValuePair("googAutoGainControl", "true"))
        })
        local = factory!!.createAudioTrack("gaminghub-voice", source)
        peer!!.addTrack(local, listOf("gaminghub-audio"))
        peer!!.setBitrate(12000, 24000, 32000)
        if (caller) offer(false)
        retry = control.schedule({ if (!closed && peer?.connectionState() != PeerConnection.PeerConnectionState.CONNECTED) reconnect() }, 20, TimeUnit.SECONDS)
    }
    private fun observer(created: ((SessionDescription) -> Unit)? = null, set: (() -> Unit)? = null): SdpObserver = object : SdpObserver {
        override fun onCreateSuccess(sdp: SessionDescription) = dispatch { created?.invoke(sdp) }
        override fun onSetSuccess() = dispatch { set?.invoke() }
        override fun onCreateFailure(reason: String) = dispatch { fail("webrtc_sdp_create_failed") }
        override fun onSetFailure(reason: String) = dispatch { fail("webrtc_sdp_set_failed") }
    }
    private fun publish(sdp: SessionDescription) {
        peer?.setLocalDescription(observer(set = {
            signal(if (sdp.type == SessionDescription.Type.OFFER) "voice_offer" else "voice_answer",
                JSONObject().put("sdp", sdp.description).put("type", sdp.type.canonicalForm()).toString())
        }), sdp)
    }
    private fun offer(restart: Boolean) {
        if (peer?.signalingState() != PeerConnection.SignalingState.STABLE) return
        val constraints = MediaConstraints()
        if (restart) constraints.mandatory.add(MediaConstraints.KeyValuePair("IceRestart", "true"))
        peer?.createOffer(observer(created = { publish(it) }), constraints)
    }
    fun receive(kind: String, payload: String) {
        if (closed) return
        val data = JSONObject(payload)
        if (kind == "voice_ice") {
            val candidate = IceCandidate(data.optString("sdpMid", "0"), data.optInt("sdpMLineIndex", 0), data.getString("candidate"))
            if (peer?.remoteDescription == null) { if (candidates.size < 128) candidates.add(candidate) }
            else peer?.addIceCandidate(candidate)
            return
        }
        if (kind !in listOf("voice_offer", "voice_answer")) return
        if (kind == "voice_offer" && caller) return // Fixed role prevents offer glare.
        if (kind == "voice_answer" && peer?.signalingState() != PeerConnection.SignalingState.HAVE_LOCAL_OFFER) return
        val type = if (kind == "voice_offer") SessionDescription.Type.OFFER else SessionDescription.Type.ANSWER
        peer?.setRemoteDescription(observer(set = {
            while (candidates.isNotEmpty()) peer?.addIceCandidate(candidates.removeFirst())
            if (type == SessionDescription.Type.OFFER) peer?.createAnswer(observer(created = { publish(it) }), MediaConstraints())
        }), SessionDescription(type, data.getString("sdp")))
    }
    private fun reconnect() {
        retry?.cancel(false)
        if (++attempts > 3) { fail("webrtc_connection_failed"); return }
        status("reconnecting", "")
        if (caller) offer(true)
        retry = control.schedule({ if (!closed && peer?.connectionState() != PeerConnection.PeerConnectionState.CONNECTED) reconnect() }, 8, TimeUnit.SECONDS)
    }
    @Suppress("DEPRECATION")
    private fun route() {
        if (!ownsRoute || closed) return
        val wired = mutableSetOf(AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES, AudioDeviceInfo.TYPE_USB_DEVICE)
        if (Build.VERSION.SDK_INT >= 26) wired.add(AudioDeviceInfo.TYPE_USB_HEADSET)
        if (Build.VERSION.SDK_INT >= 31) {
            val available = manager.availableCommunicationDevices
            val selected = available.firstOrNull { it.type in wired }
                ?: available.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            check(selected != null && manager.setCommunicationDevice(selected)) { "communication_route_failed" }
        } else manager.isSpeakerphoneOn = !manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { it.type in wired }
    }
    @Suppress("DEPRECATION")
    fun stop() {
        if (closed) return
        closed = true; retry?.cancel(false); retry = null
        local?.setEnabled(false)
        peer?.close(); peer?.dispose(); peer = null
        local?.dispose(); local = null; source?.dispose(); source = null
        factory?.dispose(); factory = null; adm?.release(); adm = null; candidates.clear()
        if (ownsRoute) {
            manager.unregisterAudioDeviceCallback(devices)
            if (Build.VERSION.SDK_INT >= 31) {
                val previous = previousDevice
                if (previous == null || !manager.setCommunicationDevice(previous)) manager.clearCommunicationDevice()
            } else manager.isSpeakerphoneOn = previousSpeaker
            manager.mode = previousMode; ownsRoute = false
        }
        if (ownsFocus) {
            if (Build.VERSION.SDK_INT >= 26) focus?.let { manager.abandonAudioFocusRequest(it) }
            else manager.abandonAudioFocus(focusListener)
            ownsFocus = false
        }
    }
}
