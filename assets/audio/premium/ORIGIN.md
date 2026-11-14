# Gaming Hub original audio
All 14 WAV files were composed and synthesized specifically for this project from sine partials and deterministic noise using tools/generate_premium_audio.py. No external recordings, sample packs, songs, artist imitations, APIs or downloads are incorporated. Commercial integration is intended; there are no third-party sample attribution requirements. The generator and musical score are included for provenance and reproducibility.

Music: Menu Sunrise, 96 BPM, 8 bars / 20 seconds, Cmaj9 / Am7 / Fmaj9 / Gsus. Plucked keys, soft pad, gentle bass and quiet shaker. Circular tails preserve loop continuity. Runtime uses explicit PCM frame loop bounds.

14 mono 16-bit PCM WAV files at 22050 Hz; total 1,268,478 bytes. No streaming/network dependency. Godot imports use uncompressed PCM for predictable loop bounds; cache-on-use effects and one persistent music player. Music playback -8 dB; managed effects -12/-14 dB plus UI bus attenuation. No audio modifications to the native voice engine.

Events: startup; click; navigation/back; selection; room_create; player_join; all_ready; countdown; round_start; correct; incorrect; victory; results. Effects are rate-limited with bounded simultaneous voices. Sound quiz playback stops managed music/effects and prevents new effects until its clip completes.
