package com.iroaa15.gaminghub.voice;

import android.app.Activity;
import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;
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
        if (engine != null) engine.stop();
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
