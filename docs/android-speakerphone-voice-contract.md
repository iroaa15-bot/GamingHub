# Gaming Hub: speakerphone voice implementation contract

Status: experimental architecture specification. **Not an implemented Android echo canceller.**

## Required behavior
- Voice is strictly opt-in per player. Game networking and match recovery never depend on voice media.
- Android players can use built-in speaker + microphone without headphones.
- On Android, audio recording should use a native voice-communication audio source and route playback through a communication audio path, with platform AcousticEchoCanceler (AEC), NoiseSuppressor (NS), and AutomaticGainControl (AGC) enabled only if available and verified.
- Do not claim guaranteed AEC: availability and effectiveness depend on Android hardware, firmware, routing, and OS.
- On Windows, retain the verified Godot local capture/playback path until an independently tested replacement exists.

## Technical integration
1. Build a Godot 4.5 Android plugin using the Android Gradle build template; keep existing debug non-Gradle export working until plugin build is validated.
2. Native Java/Kotlin audio capture: AudioRecord with MediaRecorder.AudioSource.VOICE_COMMUNICATION, 16 kHz mono PCM16, 20 ms (320 samples), using an appropriately sized ring buffer.
3. Create AcousticEchoCanceler/NoiseSuppressor/AutomaticGainControl on the actual AudioRecord audio session ID, check isAvailable(), setEnabled(), and record the resulting enabled status. Disable/release all effects on stop.
4. Native output: AudioTrack in MODE_STREAM with AudioAttributes.USAGE_VOICE_COMMUNICATION, 16 kHz mono PCM16. Configure AudioManager communication mode and speaker routing when session starts; restore prior audio mode and route when it stops. Handle Android version differences and audio-focus interruptions.
5. Expose Godot calls start_voice(), stop_voice(), poll_pcm(), push_pcm(), diagnostics(). The existing consent-gated voice signaling remains authoritative.
6. Keep PCM packets on a best-effort queue independent of gameplay messages. Prefer Opus/WebRTC media for a production-quality implementation; raw PCM over WebSocket is an interim transport.
7. Android permission: RECORD_AUDIO is requested only after consent; never record in background.
8. Guard plugin access by OS feature checks; a missing plugin must fail voice only, not crash or disconnect the game.

## Verification gates
- Native Android plugin compiles in GitHub Actions, debug APK installs, and diagnostics confirm whether AEC/NS/AGC are supported and enabled.
- Local built-in speaker/mic loopback tested carefully at moderate volume; use an external test device to assess acoustic echo (self-loopback alone is not an AEC quality test).
- Two Android phones, no headphones, two-way voice for 10 minutes while playing; no game disconnects, clear speech, no sustained echo/howl, bounded latency.
- Android ↔ Windows call and interrupted-network recovery tested separately.
- Do not merge experimental client into main until these checks pass.
