# Native speakerphone plugin build (experimental)

This is a standalone Android library module, **not** yet a working Godot plugin APK.

## Build prerequisites
- Java 17, Android SDK 35, Gradle 8.9+ (compatible with Android Gradle Plugin 8.7.3)
- Godot **4.5.1** Android library AAR from the matching Android build templates or Godot Android source build.
- Pass the exact matching AAR path via `-PgodotAar=/absolute/path/to/godot-lib.release.aar`.

From `native/android/voice`, run:

```sh
gradle assembleRelease -PgodotAar=/absolute/path/to/godot-lib.release.aar
```

The output should be `build/outputs/aar/voice-release.aar` (check the actual Gradle output filename). The Godot plugin Java class, manifest registration, runtime permission and AEC support still require end-to-end validation.

## Remaining integration
1. Verify the Java bridge against the **actual Godot 4.5.1** Android plugin API; fix API mismatches revealed by Gradle.
2. Build AAR and place it under `android/plugins/` alongside a `.gdap` plugin descriptor, using Godot's Android Gradle export template.
3. Enable Gradle export in a **separate experimental preset**, not the existing non-Gradle debug preset.
4. Route native PCM frames to the existing consent-gated WebSocket relay, avoiding simultaneous Godot microphone capture.
5. Test on two real Android phones using built-in speaker and microphone; measure echo, clipping, jitter and reconnection before promoting to main.

Do not report AEC as operational merely because `AcousticEchoCanceler.isAvailable()` is true. It must be enabled on the real recording session and verified with live two-way speech.
