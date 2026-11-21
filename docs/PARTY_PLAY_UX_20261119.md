# Social party play UX

Base: PR #21 head `63cafe4d79b93fb85ad9a4363b4d073909ff2983`.
Scope: all six online social games, a common frame for photo/quiz rooms, fixed
answer controls and pending-answer feedback, and modern local social setup.
Account storage, native audio, server rules, scoring and consent are unchanged.

## Behavior

- A dedicated, persistent lobby/match layout replaces the rebuilt social
  panel. The common entry, invitation, agreement, identity, and room transport
  remain in use. The existing host-ready/start contract remains authoritative.
- Stable player seats, a readable prompt, actor/listener instructions, and a
  bottom action area replace the generic stacked photo-game controls.
- Existing call/mute controls live in a fixed footer outside scrolling content.
  No voice permission, consent, epoch, mute, focus, or recovery behavior changes.
- Participation, secret story commitment, voting, and power actions use the
  current card ID. A successful send locks the action controls
  until a canonical phase/card transition, rejection, or resumed room
  snapshot. Repeated snapshots do not recreate controls or replay animations.
- A resume acknowledgement alone does not unlock answers. The following active
  authoritative snapshot permits an explicit retry; the UI never resends it.
- Round results show server-provided awards separately from match totals. The
  host still explicitly advances. Final results support ties and preserve calls
  until exit. No account XP or persisted rewards are invented.
- Text/mixed chat and report/block actions remain available under Chat & report.
- Exit and Android Back request confirmation. Reduced motion disables the brief
  prompt fade. Only the existing performance games show their real timer;
  Open Heart and other untimed games remain untimed.
- Compact in-match player cards keep the entire prompt visible with six seats.
  Performers' cards and power offers remain private. Another player's vote does
  not acknowledge a pending local vote; only the local vote's canonical state does.
- Photo/quiz rooms reuse their existing images, media scheduling, clue privacy,
  ordering and memory mechanics. MCQ/submit/next controls sit outside scrolling
  content. Pending-answer locking survives frame updates; correctness appears
  only after the authoritative reveal. Final photo draws are labelled correctly.
- Local social screens use shared midnight/purple surfaces and brief transitions. Individual name
  fields with a 2–6-player control adapt the existing setup input; local engines,
  secret handovers, rules, scoring and timers are unchanged.

## Validation and limits

The new fixture covers Arabic/English, 2–6 players, lobby, actor, pause, results,
finish, closure, stable prompt identity and mute coordinates, duplicate-send
locking, and resume without replay. The existing 120-case social UI fixture is
adapted to the new layout while retaining checks for all six games.

The WebSocket UI test now exercises all ten rounds, checks a same-frame double
tap, and requires both clients to finish 50–50. The dedicated validation workflow
runs it against an ephemeral loopback server with the draft content flag.

Local headless layout, 120-case social UI, voice continuity, audio-policy
assertions, account progress isolation, and 12 party/room model cases passed.
Audio-policy teardown emits existing resource-leak diagnostics; its assertions
pass, so those diagnostics are reported separately rather than called a clean run.

After network permission was granted, local real-WebSocket validation passed:
the ten-round social UI match, 15 server transport/privacy cases, and cinema/sound
UI answer-to-result flows. New photo/quiz fixed-control and local six-game setup
fixtures passed. Native six-player captures were inspected and prompt clipping
was fixed by compacting player cards. Additional final captures are in CI.

Both phones retain matching progress/owner/language hashes after update with the
original development certificate. An unsupported source-overlay test package was
rolled back; the official CI export is used for device acceptance. Phone/audible
acceptance is in progress on the unlocked devices. A real Open Heart room and
voice connection have now been established; audible quality is awaiting the
owner's listening confirmation. This does not yet prove a complete phone match.
No production deployment or merge. Hosted account rewards are not proven by a
memory-only local match. Consult the PR for the latest checks and device evidence.

The supplied fourteen-image pack is traced in
`VISUAL_REFERENCE_ACCEPTANCE_20261119.md`. A central compact gameplay palette now
shares the existing navy/purple identity, and local quiz HUDs remove duplicate
progress/metadata so answers and hints fit more comfortably. No rule or reward
values change. All ten core games pass local complete-match validator and reward
idempotency checks in AR/EN. The native capture harness produces 90 seeded states
per before/after set at 420×900; these are explicitly desktop fixtures.

## Follow-up acceptance

1. Inspect native renders at narrow/large-text sizes; correct any clipping.
2. Run a complete two-phone match with the new debug APK and record the UI.
3. Hear both directions through notifications, mute, interruption, and reconnect.
4. Confirm progress hashes before/after APK update and hosted reward persistence.
5. Review the new online/local screens in their actual mechanics and retain all
   secret-card/vote and media-timing protections before release acceptance.
