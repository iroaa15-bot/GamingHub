# Reference-driven UI and remaining identity correction

## Implemented in this batch

The shared native skin now uses a violet/cyan frame, glossy semantic buttons and lightweight castle silhouettes. No reference montage was embedded as an interactive screen and no replacement art was generated. Existing approved welcome art and official provider marks remain intact; welcome stays at three login actions and a large styled language selector.

Room codes, copy and share now use one compact row. Player portraits are88px for2 players,72px for3–4-player lobbies and64px for5–6-player lobbies; dense active layouts retain56px. Host/turn borders, readable names and actual connection/readiness chips are separate. Empty seats use a plus placeholder. Peer microphone states are not fabricated from the aggregate voice flag.

All six local social games and their shared online screen use a cream/gold native prompt card. Shared cinema/sound questions have framed native question panels. Server-revealed correct answers are green; a player's incorrect selection is red, only after the answer phase. Sound progress follows the actual audio playback position. No protected film stills, new sounds, store, payment, QR scanner or gameplay rules were added.

Closed photo/quiz snapshots now hide old images, captions, pending questions, next-round actions and both timer widgets immediately.

`VISUAL_REFERENCE_MAP_20261113.md` maps the supplied references to actual components and records exclusions. This is a first shared implementation, not a claim of pixel-perfect or complete phone acceptance.

## Verification actually run

-54 native rendered fixture captures: Arabic/English welcome/catalog/mode/settings/profile;2–6-player lobby/question/results; cinema/sound question/feedback; actual first playable card in all six local social scenes. Output is external to the repository under `outputs/reference-native-fixtures`. These are desktop fixtures, not device multiplayer evidence.
-120 social UI state cases,2–6-player card layout, original sixteen-game catalog routes, closed-room UI regression and social rules regression passed.
- Runtime button inventory:482 instances, zero enabled controls without a handler. This does not prove every external operation or physical tap.
- Godot editor import completed without GDScript errors. Desktop shader caching is unavailable because the user-data directory is read-only; native rendering still completed. Desktop language persistence is not accepted by these captures.

## Historical provider separation

`provider_accounts.py` separates old shared Google/Facebook identities on a subsequent verified provider login. A password account keeps its own data; otherwise Google retains the historical account when present. Other provider accounts start with zero points and empty progress. Existing uploaded photos, point ledgers and player rows are retained on the original account rather than duplicated. New provider avatars can populate the separate account from the verified provider response.

Old shared access/refresh sessions are revoked because they did not record which provider authenticated them. The current verified login gets a fresh session. Locks serialize concurrent provider logins and the provider mapping is re-read after locking.

Six PostgreSQL regression cases are prepared (Google first, Facebook first, concurrent; with/without a password account). Python compilation and collection passed. **Database execution has not passed yet:** no local PostgreSQL is available and hosted external DB access remains closed. The integrated CI workflow explicitly includes the new cases. No hosted account migration or server deployment has occurred; do not call separation production-ready before these tests and a real provider re-test.

## Still outstanding

Physical acceptance of this exact new UI build, full functional button audit, hosted voice continuity/recovery, OPPO task-return native crash, editorial/English completion of content, licensed sound expansion, all provider/device combinations, and release-signing/AAB acceptance. Main/production remain unchanged and PR19 stays a draft.
