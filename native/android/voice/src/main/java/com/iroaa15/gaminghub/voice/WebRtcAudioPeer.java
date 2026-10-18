package com.iroaa15.gaminghub.voice;

import android.content.Context;
import android.media.AudioManager;
import android.media.AudioDeviceInfo;
import android.os.Build;
import org.webrtc.AudioSource;
import org.webrtc.AudioTrack;
import org.webrtc.IceCandidate;
import org.webrtc.MediaConstraints;
import org.webrtc.PeerConnection;
import org.webrtc.PeerConnectionFactory;
import org.webrtc.SdpObserver;
import org.webrtc.SessionDescription;
import org.webrtc.audio.JavaAudioDeviceModule;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.ConcurrentLinkedQueue;

/** Isolated WebRTC/Opus voice peer. Does not start until both players consent. */
public final class WebRtcAudioPeer {
    private final Context context;
    private PeerConnectionFactory factory;
    private PeerConnection peer;
    private AudioSource source;
    private AudioTrack track;
    private JavaAudioDeviceModule audioModule;
    private final ConcurrentLinkedQueue<String> events = new ConcurrentLinkedQueue<>();
    private boolean started;
    private AudioManager audioManager;
    private int previousAudioMode = AudioManager.MODE_NORMAL;
    private boolean previousSpeakerphoneOn;
    private boolean routingConfigured;
    private boolean remoteSdpReady;
    private boolean localSdpReady;
    private final List<IceCandidate> pendingLocalCandidates = new ArrayList<>();
    private final List<IceCandidate> pendingCandidates = new ArrayList<>();

    public WebRtcAudioPeer(Context context) { this.context = context.getApplicationContext(); }

    public synchronized boolean start() {
        if (started) return true;
        try {
            configureSpeakerphone();
            PeerConnectionFactory.initialize(PeerConnectionFactory.InitializationOptions.builder(context).createInitializationOptions());
            audioModule = JavaAudioDeviceModule.builder(context)
                .setUseHardwareAcousticEchoCanceler(true)
                .setUseHardwareNoiseSuppressor(true).createAudioDeviceModule();
            factory = PeerConnectionFactory.builder()
                .setAudioDeviceModule(audioModule)
                .createPeerConnectionFactory();
            source = factory.createAudioSource(new MediaConstraints());
            track = factory.createAudioTrack("gaminghub_voice", source);
            List<PeerConnection.IceServer> ice = new ArrayList<>();
            ice.add(PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer());
            PeerConnection.RTCConfiguration config = new PeerConnection.RTCConfiguration(ice);
            peer = factory.createPeerConnection(config, new PeerConnection.Observer() {
                @Override public void onSignalingChange(PeerConnection.SignalingState state) {}
                @Override public void onIceConnectionChange(PeerConnection.IceConnectionState state) { events.add("state|" + state.name()); }
                @Override public void onIceConnectionReceivingChange(boolean receiving) {}
                @Override public void onIceGatheringChange(PeerConnection.IceGatheringState state) {}
                @Override public void onIceCandidate(IceCandidate c) {
                    synchronized (WebRtcAudioPeer.this) {
                        if (localSdpReady) {
                            events.add("ice|" + c.sdpMid + "|" + c.sdpMLineIndex + "|" + c.sdp);
                        } else if (pendingLocalCandidates.size() < 64) {
                            pendingLocalCandidates.add(c);
                        }
                    }
                }
                @Override public void onIceCandidatesRemoved(IceCandidate[] candidates) {}
                @Override public void onAddStream(org.webrtc.MediaStream stream) {}
                @Override public void onRemoveStream(org.webrtc.MediaStream stream) {}
                @Override public void onDataChannel(org.webrtc.DataChannel channel) {}
                @Override public void onRenegotiationNeeded() {}
                @Override public void onAddTrack(org.webrtc.RtpReceiver receiver, org.webrtc.MediaStream[] streams) {}
            });
            if (peer == null) throw new IllegalStateException("PeerConnection unavailable");
            peer.addTrack(track, Collections.singletonList("gaminghub_audio"));
            started = true;
            return true;
        } catch (RuntimeException ex) {
            stop();
            return false;
        }
    }

    private void configureSpeakerphone() {
        audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (audioManager == null) return;
        previousAudioMode = audioManager.getMode();
        previousSpeakerphoneOn = audioManager.isSpeakerphoneOn();
        routingConfigured = true;
        audioManager.setMode(AudioManager.MODE_IN_COMMUNICATION);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            for (AudioDeviceInfo device : audioManager.getAvailableCommunicationDevices()) {
                if (device.getType() == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                    audioManager.setCommunicationDevice(device);
                    return;
                }
            }
        }
        audioManager.setSpeakerphoneOn(true);
    }

    private void restoreAudioRouting() {
        if (!routingConfigured || audioManager == null) return;
        routingConfigured = false;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) audioManager.clearCommunicationDevice();
        audioManager.setSpeakerphoneOn(previousSpeakerphoneOn);
        audioManager.setMode(previousAudioMode);
        audioManager = null;
    }

    private SdpObserver observer(String type) {
        return new SdpObserver() {
            @Override public void onCreateSuccess(SessionDescription sdp) {
                if (peer == null) return;
                peer.setLocalDescription(observer("local_" + type + "|" + sdp.description), sdp);
            }
            @Override public void onSetSuccess() {
                if (type.startsWith("local_offer|") || type.startsWith("local_answer|")) {
                    synchronized (WebRtcAudioPeer.this) {
                        events.add(type.substring(6));
                        localSdpReady = true;
                        for (IceCandidate c : pendingLocalCandidates) {
                            events.add("ice|" + c.sdpMid + "|" + c.sdpMLineIndex + "|" + c.sdp);
                        }
                        pendingLocalCandidates.clear();
                    }
                }
                if (type.startsWith("remote_")) {
                    synchronized (WebRtcAudioPeer.this) {
                        remoteSdpReady = true;
                        if (peer != null) {
                            for (IceCandidate candidate : pendingCandidates) peer.addIceCandidate(candidate);
                        }
                        pendingCandidates.clear();
                    }
                }
                if ("remote_offer".equals(type)) createAnswer();
            }
            @Override public void onCreateFailure(String error) { events.add("error|" + error); }
            @Override public void onSetFailure(String error) { events.add("error|" + error); }
        };
    }

    public synchronized void createOffer() {
        if (peer != null) peer.createOffer(observer("offer"), new MediaConstraints());
    }
    private synchronized void createAnswer() {
        if (peer != null) peer.createAnswer(observer("answer"), new MediaConstraints());
    }
    public synchronized void remoteDescription(String kind, String sdp) {
        if (peer == null) return;
        if (!"offer".equals(kind) && !"answer".equals(kind)) return;
        peer.setRemoteDescription(observer("offer".equals(kind) ? "remote_offer" : "remote_answer"),
            new SessionDescription("offer".equals(kind) ? SessionDescription.Type.OFFER : SessionDescription.Type.ANSWER, sdp));
    }
    public synchronized void remoteCandidate(String candidate, String mid, int line) {
        if (peer == null || candidate == null || candidate.isEmpty() || line < 0) return;
        IceCandidate ice = new IceCandidate(mid, line, candidate);
        if (remoteSdpReady) peer.addIceCandidate(ice);
        else if (pendingCandidates.size() < 64) pendingCandidates.add(ice);
    }
    public synchronized boolean setMuted(boolean muted) {
        if (!started || track == null) return false;
        return track.setEnabled(!muted) && track.enabled() == !muted;
    }
    public String pollEvent() { String event = events.poll(); return event == null ? "" : event; }
    public synchronized void stop() {
        started = false;
        remoteSdpReady = false;
        localSdpReady = false;
        pendingCandidates.clear();
        pendingLocalCandidates.clear();
        if (peer != null) { peer.dispose(); peer = null; }
        if (track != null) { track.dispose(); track = null; }
        if (source != null) { source.dispose(); source = null; }
        if (factory != null) { factory.dispose(); factory = null; }
        if (audioModule != null) { audioModule.release(); audioModule = null; }
        events.clear();
        restoreAudioRouting();
    }
}