# Local validation evidence

See [the Arabic handoff](../ANDROID_VOICE_HANDOFF_AR.md) for commands and limits.

Final local runs: 213 offline Python tests, 75 server tests, 3 daily-content tests,
14 JVM tests, native Debug/Release AAR builds, clean Lint, D8 API 24 conversion,
and executable Godot import/voice/room recovery/smoke/release/boot checks.

Android capture/playback is simulated at the JNI boundary in the Godot tests.
No physical Android microphones/speakers were tested, no APK was created and no
production server was changed. Absolute workspace paths and ANSI colors were
removed from copied text logs. summary.json pins the validated sources and AARs.
