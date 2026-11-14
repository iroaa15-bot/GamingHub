# Physical acceptance, 13 November 2026

Installed source: `9a8fd46fa86573993d423a0a2b73feefb4106d40`, same certificate and preserved progress on Android 9 OPPO and Android 16 S23. No production change or deployment.

## Recorded evidence

- Agent created Open Heart room 330704 through the S23 UI; OPPO joined through its UI. Both confirmed readiness.
- Completed all ten rounds, alternating physical devices. Both displayed final scores 50–50. Player cards remained visible in active rounds and results. No foreground crash observed during this match.
- Owner confirmed audible voice in both directions after enabling the call in round one. Later screenshots showed OPPO transmission muted. Cause is unresolved: only the explicit mute-button handler changes the adapter's `muted` property; moving controls between result/active layouts can make repeated coordinate taps ambiguous. Do not claim uninterrupted two-way speech for the entire match.
- Video `outputs/GamingHub-full-match-9a8fd46.mp4` is 479.32 seconds, 540x1200, with the final result verified in its last frame. Screen recording has no audio. Screenshots `s23-9a-final.png` and `oppo-9a-final.png` show both results.
- Transport was a loopback development SocialHub through ADB reverse, not the hosted service. Scores in this fixture were memory-only, not PostgreSQL account awards. Neither account persistence nor internet recovery is accepted by this match.
- Debug endpoint files restored from exact pre-test backups on both devices, reverse8897 removed, keep-awake settings verified 0 on both. OPPO display permission denial was respected.

## Follow-up source fixes, not yet in the recorded APK

Hide irrelevant photo difficulty from social room creation; show player/round readiness information; retain player cards when returning to a lobby; expose text chat only in text/mixed modes; display a draw instead of player zero. These fixes passed 120 Arabic/English UI cases, including 2–6 players, mode changes, draw and lobby return, plus the actual UI/WebSocket creation/join/start/score test. Voice continuity regression also preserves explicit mute while ordinary round snapshots never set it automatically. This is a fixture test, not proof of native audio continuity.

## Still open

Native OPPO task-return destroyed-mutex crash; physical hosted voice/reconnect and provider matrix on the latest APK; migration of the old linked QA account; complete content editorial/English review; comprehensive button acceptance; release signing and AAB verification. New social server functionality remains unhosted and disabled by default unless explicitly enabled. Do not merge or label production-ready.
