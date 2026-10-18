package com.iroaa15.gaminghub.voice;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.media.AudioDeviceInfo;
import android.media.AudioTrack;
import android.media.MediaRecorder;
import android.media.audiofx.AcousticEchoCanceler;
import android.media.audiofx.AutomaticGainControl;
import android.media.audiofx.NoiseSuppressor;
import android.os.Build;
import android.os.Process;

/**
 * Experimental native 16 kHz speakerphone audio engine.
 * Requires RECORD_AUDIO permission granted by the app before start().
 * This class is not wired into the Godot APK yet; a Godot Android plugin
 * must own its lifecycle and call readPcm()/writePcm() off the UI thread.
 */
public final class SpeakerphoneAudioEngine {
    public static final int SAMPLE_RATE = 16000;
    public static final int PACKET_SAMPLES = 320;
    private final Context context;
    private AudioManager manager;
    private AudioRecord recorder;
    private AudioTrack player;
    private AcousticEchoCanceler aec;
    private NoiseSuppressor ns;
    private AutomaticGainControl agc;
    private int previousMode = AudioManager.MODE_NORMAL;
    private boolean previousSpeakerphone;
    private boolean running;
    private boolean changedCommunicationDevice;

    public SpeakerphoneAudioEngine(Context context) {
        this.context = context.getApplicationContext();
    }

    public synchronized void start() {
        if (running) return;
        manager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (manager == null) throw new IllegalStateException("No AudioManager");
        previousMode = manager.getMode();
        previousSpeakerphone = manager.isSpeakerphoneOn();
        try {
            manager.setMode(AudioManager.MODE_IN_COMMUNICATION);
            // Route through the handset speaker, not Bluetooth/headset by default.
            // Only restore a communication route if this engine selected it.
            if (Build.VERSION.SDK_INT >= 31) {
                for (AudioDeviceInfo device : manager.getAvailableCommunicationDevices()) {
                    if (device.getType() == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                        changedCommunicationDevice = manager.setCommunicationDevice(device);
                        break;
                    }
                }
            } else {
                manager.setSpeakerphoneOn(true);
            }
            int inputMin = AudioRecord.getMinBufferSize(SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
            int outputMin = AudioTrack.getMinBufferSize(SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT);
            if (inputMin <= 0 || outputMin <= 0) throw new IllegalStateException("Unsupported PCM format");
            recorder = new AudioRecord(MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                Math.max(inputMin, PACKET_SAMPLES * 2 * 8));
            if (recorder.getState() != AudioRecord.STATE_INITIALIZED)
                throw new IllegalStateException("AudioRecord init failed");
            int sessionId = recorder.getAudioSessionId();
            if (AcousticEchoCanceler.isAvailable()) {
                aec = AcousticEchoCanceler.create(sessionId);
                if (aec != null) aec.setEnabled(true);
            }
            if (NoiseSuppressor.isAvailable()) {
                ns = NoiseSuppressor.create(sessionId);
                if (ns != null) ns.setEnabled(true);
            }
            if (AutomaticGainControl.isAvailable()) {
                agc = AutomaticGainControl.create(sessionId);
                if (agc != null) agc.setEnabled(true);
            }
            player = new AudioTrack.Builder()
                .setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setAudioFormat(new AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                .setBufferSizeInBytes(Math.max(outputMin, PACKET_SAMPLES * 2 * 8))
                .setTransferMode(AudioTrack.MODE_STREAM).build();
            if (player.getState() != AudioTrack.STATE_INITIALIZED)
                throw new IllegalStateException("AudioTrack init failed");
            recorder.startRecording();
            player.play();
            running = true;
        } catch (RuntimeException e) {
            stop();
            throw e;
        }
    }

    /** Read one 20 ms PCM16 packet; invoke on a dedicated worker thread. */
    public synchronized int readPcm(short[] packet) {
        if (!running || packet == null || packet.length < PACKET_SAMPLES) return -1;
        return recorder.read(packet, 0, PACKET_SAMPLES, AudioRecord.READ_NON_BLOCKING);
    }

    /** Play PCM16 samples; invoke on a dedicated worker thread. */
    public synchronized int writePcm(short[] packet, int count) {
        if (!running || packet == null || count < 0 || count > packet.length) return -1;
        return player.write(packet, 0, count, AudioTrack.WRITE_NON_BLOCKING);
    }

    public synchronized boolean isRunning() { return running; }
    public synchronized boolean aecEnabled() { return aec != null && aec.getEnabled(); }
    public synchronized boolean nsEnabled() { return ns != null && ns.getEnabled(); }
    public synchronized boolean agcEnabled() { return agc != null && agc.getEnabled(); }

    public synchronized void stop() {
        running = false;
        if (recorder != null) {
            try { if (recorder.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) recorder.stop(); }
            catch (IllegalStateException ignored) {}
            recorder.release();
            recorder = null;
        }
        if (player != null) {
            try { if (player.getPlayState() == AudioTrack.PLAYSTATE_PLAYING) player.stop(); }
            catch (IllegalStateException ignored) {}
            player.release();
            player = null;
        }
        if (aec != null) { aec.release(); aec = null; }
        if (ns != null) { ns.release(); ns = null; }
        if (agc != null) { agc.release(); agc = null; }
        if (manager != null) {
            if (Build.VERSION.SDK_INT >= 31 && changedCommunicationDevice) {
                manager.clearCommunicationDevice();
                changedCommunicationDevice = false;
            }
            manager.setMode(previousMode);
            if (Build.VERSION.SDK_INT < 31) manager.setSpeakerphoneOn(previousSpeakerphone);
            manager = null;
        }
    }
}
