# Core game redesign — 20 November 2026

The ten original games now enter a native round-setup screen before offline
play. Difficulty, content category/collection and session length adapt the
existing rules. Supported quiz styles remain classic, survival, local rival and
blitz; memory remains untimed and photo sessions keep turn-based limits.
Advanced original modes remain reachable through More play options.

The complete local catalog is visible by default. Validated remote ordering and
visibility settings still apply. Mode screens use the existing game artwork.
Quiz answers use two columns and a fixed bottom dock; text answers, order submit,
picture guessing and hints reuse the real controls. At large reading sizes,
choice answers remain in the scroll area to avoid an oversized footer. Real
pause/resume stops the existing blitz timer, and result/navigation actions are
fixed at the bottom. Picture questions and candidate names use expandable lists;
the owner's secret image remains hidden. Memory retains its matching rules with
a short optional reveal fade. Reduced motion remains respected.

Validation: core_redesign_flow exercises setup-to-play for all ten games in AR/EN,
the actual start action, fixed docks, pause/resume and a real timer. The separate
complete-match acceptance uses answer validators and reward idempotency. Native
reference capture now produces 130 states (including setup and pause). These are
desktop renders; physical acceptance of the new build is a separate gate.

## Android 16 Back compatibility

The tested second device identifies as **reeder S23_SE, Android 16**, not Samsung
S23. A native SIGABRT occurred during Android Back after the successful two-phone
match/audio/reconnect tests. The saved backtrace enters GodotRenderer's render
thread teardown and aborts on a destroyed mutex. No claim that engine teardown is
globally repaired is made.

Target-36 Android Back can bypass legacy KEYCODE_BACK/onBackPressed handlers.
The pinned Godot 4.5.1 build now explicitly sets
`android:enableOnBackInvokedCallback="false"` on the generated application
manifest, preserving existing scripted Back/confirmation behavior. This temporary
compatibility option is documented by Android; build gates inspect the final APK
manifest. It does not change native voice AARs, permissions, scoring or storage.

Sources: [Android 16 Back behavior](https://developer.android.com/about/versions/16/behavior-changes-16#predictive-back),
[Godot 4.5.1 Android template](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/java/app/src/com/godot/game/GodotApp.java).

Still open: full fourteen-reference parity, Maana's incomplete content/integration,
cinema/sound 200-item targets, exhaustive physical button/account acceptance and
production release approval. No merge, production change or paid service.
