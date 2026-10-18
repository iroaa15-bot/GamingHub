package com.iroaa15.gaminghub.voice;

import android.app.Activity;
import android.Manifest;
import android.content.pm.PackageManager;
import android.util.Base64;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import androidx.core.content.ContextCompat;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Godot 4 Android plugin bridge for native speakerphone audio.
 * The application must obtain RECORD_AUDIO permission after player consent.
 * This bridge deliberately does not start recording automatically.
 */
public final class GamingHubVoicePlugin extends GodotPlugin {
    private SpeakerphoneAudioEngine engine;
    private final short[] capture = new short[SpeakerphoneAudioEngine.PACKET_SAMPLES];
    private int capturedSamples = 0;

    public GamingHubVoicePlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "GamingHubVoice";
    }

    @UsedByGodot
    public boolean startVoice() {
        Activity activity = getActivity();
        if (activity == null || ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) return false;
        try {
            if (engine == null) engine = new SpeakerphoneAudioEngine(activity);
            engine.start();
            return engine.isRunning();
        } catch (RuntimeException ex) {
            if (engine != null) engine.stop();
            return false;
        }
    }

    @UsedByGodot
    public void stopVoice() {
        capturedSamples = 0;
        if (engine != null) engine.stop();
    }

    /** Poll 20ms mono PCM16; empty means no complete packet available. */
    @UsedByGodot
    public String pollPcm() {
        if (engine == null || !engine.isRunning()) return "";
        short[] remaining = new short[capture.length - capturedSamples];
        int count = engine.readPcm(remaining);
        if (count < 0) return "";
        if (count > 0) {
            System.arraycopy(remaining, 0, capture, capturedSamples, count);
            capturedSamples += count;
        }
        if (capturedSamples < capture.length) return "";
        capturedSamples = 0;
        ByteBuffer bytes = ByteBuffer.allocate(capture.length * 2).order(ByteOrder.LITTLE_ENDIAN);
        for (short sample : capture) bytes.putShort(sample);
        return Base64.encodeToString(bytes.array(), Base64.NO_WRAP);
    }

    /** Accept only the existing 640-byte voice protocol packet. */
    @UsedByGodot
    public boolean pushPcm(String encoded) {
        if (engine == null || !engine.isRunning() || encoded == null || encoded.length() != 856) return false;
        byte[] bytes;
        try {
            bytes = Base64.decode(encoded, Base64.NO_WRAP);
        } catch (IllegalArgumentException e) {
            return false;
        }
        if (bytes.length != SpeakerphoneAudioEngine.PACKET_SAMPLES * 2) return false;
        ByteBuffer data = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN);
        short[] samples = new short[SpeakerphoneAudioEngine.PACKET_SAMPLES];
        for (int i = 0; i < samples.length; i++) samples[i] = data.getShort();
        return engine.writePcm(samples, samples.length) == samples.length;
    }

    @UsedByGodot
    public boolean isRunning() {
        return engine != null && engine.isRunning();
    }

    @UsedByGodot
    public boolean isAecEnabled() {
        return engine != null && engine.aecEnabled();
    }

    @UsedByGodot
    public boolean isNsEnabled() {
        return engine != null && engine.nsEnabled();
    }

    @UsedByGodot
    public boolean isAgcEnabled() {
        return engine != null && engine.agcEnabled();
    }
}
