# Party Room — implementation contract

Status: isolated planning branch. No production game code changed.

## Fixed defaults
- Players: 6; rounds: 15; games: Pass the Bomb, Who's Most Likely, Odd One Out, Truth or Dare, Draw Disaster, Crazy Emoji, Fake It, Secret Mission.
- Voice: opt-in per player; independent microphone mute and speaker mute; text chat available.
- Preserve existing room codes, invite/join flows, voice relay, gameplay and Android builds.

## Architecture
- Feature flag party_room_enabled = false until validated.
- Room model: room_id, host_id, members, ready, game_sequence, round_index, round_state, round_deadline_server, scores, reconnect_tokens, revision.
- Server-authoritative state transitions: lobby -> ready -> round_intro -> active -> reveal -> score -> next_round -> results.
- Event contract: party.create, party.join, party.ready, party.start, party.submit, party.vote, party.timeout, party.next, party.reconnect, party.leave.
- Every event requires room membership, idempotency key, sequence/revision and validated payload. Only server scores and advances rounds.
- Voice packets use the existing isolated relay and its separate rate-limit budget. Never route voice through gameplay event limits.
- Reconnect resumes the existing room state; do not reset the match. Define host migration and bounded grace window before implementation.

## 15-round default sequence
1 bomb; 2 most_likely; 3 odd_one_out; 4 crazy_emoji; 5 fake_it; 6 truth_or_dare; 7 draw_disaster; 8 secret_mission; 9 bomb; 10 most_likely; 11 odd_one_out; 12 crazy_emoji; 13 fake_it; 14 draw_disaster; 15 secret_mission.

## Implementation order
1. Inspect current server, client, room and voice integration. Record protected file hashes and passing baseline tests.
2. Add party state machine and isolated protocol behind disabled feature flag.
3. Add room lobby and match navigation, with no changes to legacy room behavior.
4. Add each of eight games as modules; keep prompts age-appropriate and support opt-out/skip.
5. Add per-player voice opt-in and real mute integration without changing existing relay semantics.
6. Validate six real Android clients, reconnection, host departure, race conditions, network loss, audio without headset, and full 15 rounds.
7. Build debug APK on branch, inspect artifacts, then PR; never auto-merge or publish.

## Acceptance gates
- Existing gameplay, voice and build tests unchanged/passing.
- Six participants can join by code, stay connected and complete 15 rounds with consistent scores.
- All eight games have verified server-authoritative inputs, timers and outcomes.
- Voice is optional and disabling it does not affect text chat or game connection.
- Reconnect retains state and no duplicate scores occur.
- No production deployment until manual acceptance.
