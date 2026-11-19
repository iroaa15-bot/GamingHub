# Social party play UX

Base: PR #21 head `63cafe4d79b93fb85ad9a4363b4d073909ff2983`.
Scope: all six online social games. Quiz, photo, offline games, account storage,
native audio, and server rules remain independent of this social renderer.

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
  buttons until a canonical phase/card transition, rejection, or resumed room
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

Local real-WebSocket acceptance is unavailable: Python's Windows event-loop
socketpair blocks before the fixture server starts. GUI preview execution was
rejected by the automatic approval policy. Consequently no visual screenshot,
device acceptance, audible call acceptance, or APK acceptance is claimed.
CI results must be checked on the PR. No production deployment or merge.

## Follow-up acceptance

1. Inspect native renders at narrow/large-text sizes; correct any clipping.
2. Run a complete two-phone match with the new debug APK and record the UI.
3. Hear both directions through notifications, mute, interruption, and reconnect.
4. Confirm progress hashes before/after APK update and hosted reward persistence.
5. Extend the shared layout to other games only after this vertical slice is
   reviewed; preserve secret cards/votes and game-specific timers.
