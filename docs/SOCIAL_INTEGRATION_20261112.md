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
