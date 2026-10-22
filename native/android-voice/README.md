# Native Godot Android voice

The Godot v2 export plugin in `addons/gaminghub_voice` registers `GamingHubVoice`
and packages the matching AAR plus `io.github.webrtc-sdk:android:144.7559.15`.
`android_voice_bridge.gd` requests RECORD_AUDIO only after opt-in. Game navigation
does not start native audio. Voice errors are scoped independently from game moves.

The active audio path uses libwebrtc JavaAudioDeviceModule (AudioRecord/AudioTrack),
Opus/SRTP, software AEC/NS and AGC constraints, VOICE_COMMUNICATION audio focus,
speaker routing with optional wired/USB devices, bounded ICE and serialized
initialization/disposal outside Godot's render thread. The old PCM API/utilities
remain for compatibility; WebRTC does not poll PCM frames through GDScript.
Do not infer acoustic quality or OEM compatibility from compilation or JVM tests.

Use a full JDK 17, Android SDK 36 and the checked-in Gradle wrapper:

```sh
./gradlew --no-daemon --max-workers=2 testDebugUnitTest lintDebug lintRelease installPlugin
cd ../..
python tools/verify_voice_aar.py
```

Both bundled AARs are rebuilt from this branch and carry a normalized native-source
fingerprint. Do not patch/repack an AAR or bypass the fingerprint check.
See `docs/colyseus-recovery/REPORT_AR.md` and `PHONE_TEST_AR.md` for exact test scope.
