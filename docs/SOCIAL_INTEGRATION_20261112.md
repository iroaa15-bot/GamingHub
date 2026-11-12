# Current social-room and voice integration status — 12 November 2026

The new social room adapter is now connected to the composed server factory and
the actual game entry screens. Hosting remains unchanged. Hosted social content
is fail-closed unless GAMINGHUB_ENABLE_DRAFT_SOCIAL=1 is explicitly configured;
this does not approve the draft content for release. The UI negotiates common
capabilities first, so older servers show an unavailable/offline fallback.

Completed local evidence:
- 14 server cases passed (13-case social transport suite plus the targeted legacy
  photo/quiz compatibility case). These include actual authenticated WebSockets,
  all six social games, private-token resume, 90-second expiry, secret votes,
  performance timeout, power effects and duplicate-award rejection.
- Actual Godot network clients passed 30 game/player-count configurations (2–6),
  plus a complete 10-round Open Heart match. The harness reuses six transport
  sessions; normal session/message rate limits were retained.
- 120 AR/EN room UI cases passed. Actual UI create/join/readiness/button-to-score
  integration also passed over the local authenticated endpoint.
- Voice continuity regression reproduced a permanent hang-up on an old in-flight
  epoch frame before the fix, and passed afterward. Peer consent withdrawal,
  manual stop, room changes, native interruption and mute rules remain enforced.
  No native-plugin or engine crash fix is claimed.

Remaining acceptance: rebuild/install this batch, physical local/hosted matches,
voice reconnect and hearing checks, full video, legacy linked-account separation,
content editorial/English completion, licensed media expansion and native OPPO
lifecycle crash. No main/production changes, deployment or Actions were made.

## Earlier integration evidence and content inventory

# Social game integration, 12 November 2026

Source: reviewed additive files from `feature/qaadet-el-sohab-content-20261105`
at `e644fc8`. The integrated client keeps the identity, media, room and UI fixes
from PR18. No main/production change, deployment or PR merge is authorized.

The original ten games remain in their catalog. Six social entries now route to
real mode and offline scenes. Email/password stays under Profile; Google and
Facebook accounts remain independent, per the owner's explicit clarification.

## Verified locally

- Fixed native-class name collisions and malformed result-screen expressions.
- Renamed gameplay `_draw` methods: CanvasItem invoked them automatically before
  player setup, causing out-of-range access and unintended round starts.
- Stable two-card selection preserves the order of the originally offered IDs.
- Offline engine filters repeated normalized prompts without deleting source cards.
- Local secret voting and truth commitments remain hidden until resolution.
- Isolated server core now requires the complete electorate before awards, permits
  the active player to vote for another player in Who Among Us, and rejects a
  second finish. This core is **not connected to the deployed room transport**.
- Test runners reject script/assertion errors even when Godot exits with status0.

## Content limits

| Category | Records | Unique normalized Arabic prompts |
|---|---:|---:|
| Open Heart |500|500|
| Act It |550|550|
| Who Among Us |550|373|
| Show Your Skill |550|441|
| Truth or Fiction |550|550|
| Table Flip |300|300|

Total2714 unique prompts. These are structural counts, not proof of semantic
diversity or editorial acceptance. Original draft status and source files are
preserved. Full English card content, editorial replacement of repeated prompts,
and online social-game integration remain unfinished. Mode labels support AR/EN;
offline card content is currently Arabic. Online mode stays disabled honestly.

Android verification is deferred to the end at the owner's request; no phone
tests in this batch. No new APK/AAB or physical acceptance is claimed.

## Welcome and account UI follow-up

- Portrait welcome reuses the original approved artwork, with lightweight edge
  blending and the existing three sign-in actions. Provider marks are sourced
  from official branding pages; provenance is in assets/ui/providers/sources.json.
- Profile uses the shared circular avatar loader at 88px. Guest-only sessions
  cannot invoke signed-in backup, restore or photo upload controls; logout is
  hidden until authenticated. Google and Facebook identities remain independent.
- Desktop welcome and premium profile checks passed. Button inventory captured
  478 visible button instances across original and social routes with zero
  enabled buttons lacking a handler. This checks wiring, not physical clicks.
- Desktop preference persistence was blocked by the read-only Godot user-data
  directory. Android persistence and provider sign-in remain deferred.
- Evidence: outputs/welcome-portrait-preview, outputs/profile-unified-preview,
  outputs/button-inventory-20261112.json (workspace artifacts, not shipped code).

## Physical acceptance follow-up (12 November)

APK860e834 built and installed as updates on OPPO Android9 and S23 Android16;
progress hashes matched before/after. SHA256 f7dbb3a4373ca25d21b750ff2688300f0a46c8abb193487416be65294b3a2a81.
Google on S23 and Facebook on OPPO returned from real provider UI to the
server-backed profile after user completion. The legacy QA account still lists
both providers; new independent-account policy does not split existing rows.
S23 system picker/upload succeeded and displayed the selected Gaming Hub test
image with a saved confirmation. Cross-device/restart acceptance is ongoing.
OPPO reproduced native SIGABRT on GLThread during picker/task return at16:42;
this is unresolved and blocks release acceptance. No crash fix is claimed.

Physical review found unthemed social entry/local screens. A shared lightweight
backdrop now supplies the existing skin, wrapping, touch targets, padding and
Android Back handling. Catalog integration and provider-account-switch UI checks
passed locally; these follow-up changes still require APK verification.
Provider buttons no longer disable a provider just because it belongs to the
current profile, allowing a different account to be chosen. Busy requests still
lock the controls; signed-in return navigation is labelled Back to games.
