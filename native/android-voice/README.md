# Gaming Hub native Android voice (Godot 4.5.1)

Build the library without exporting an APK:

```bash
# JAVA_HOME must point to a JDK 17, not a JRE.
# ANDROID_HOME must contain platforms;android-36 and Android build tools.
./gradlew --no-daemon --max-workers=2 testDebugUnitTest lintDebug lintRelease installPlugin
cd ../..
python tools/verify_voice_aar.py
```

`installPlugin` copies both tested AAR variants to `addons/gaminghub_voice/bin`.
The enabled Godot v2 editor/export plugin selects the matching variant. The AAR manifest
registers `GamingHubVoice` and supplies RECORD_AUDIO and MODIFY_AUDIO_SETTINGS.
The app separately requests RECORD_AUDIO at runtime through `android_voice_bridge.gd`.
No WebRTC native library or TURN server is needed for this PCM relay transport.

Each AAR carries a source fingerprint, verified by the preflight and offline tests.
Rebuild after changing native source or build settings; never replace the AAR by hand.
The checked-in Gradle wrapper verifies the distribution SHA-256. No signing key is needed.

`startVoice(requestId)` and teardown are serialized off the game thread. State signals
are marshaled by GodotPlugin to its render thread. `drainCapturedFrames()` is bounded and
nonblocking. `playVoiceFrame(base64, sequence)` queues only one PCM16 LE mono 16 kHz,
20 ms frame. Godot/server validate consent epochs; audio never persists in match history.
Bluetooth routing is not selected by this implementation; speakerphone and optional
wired/USB routes are covered. Native AEC/NS availability and effectiveness depend on OEM.

Read [the implementation limits and device test handoff](../../docs/ANDROID_VOICE_HANDOFF_AR.md)
before building or distributing an app.
