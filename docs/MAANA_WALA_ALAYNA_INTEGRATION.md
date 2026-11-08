# معانا ولا علينا — integration contract (draft)

Status: rules engine added, NOT wired to room UI or server yet.

## Round lifecycle
LOBBY -> QUESTION -> SECRET_VOTE -> REVEAL -> REACTION (only if minority count > 1) -> PENALTY -> NEXT.
All 2–6 seated active players vote once. Server accepts vote 1 or 2 only, locks each vote, and broadcasts only aggregate outcome after all votes or a server deadline. Missing votes must have a documented timeout policy before release.

For minority of one: immediate penalty. Minority of two or more: reaction challenge, last valid server-received reaction loses. If several fail to react by deadline, choose a deterministic server-authoritative tie-break (e.g. seeded random) instead of depending on dictionary iteration. Server records receipt order and never accepts client timestamps. Unanimous/tied vote: no penalty, next question.

Seven penalties eliminates a player. With only two players, the minority is always one or zero (tie), so no reaction challenge. Match ends with one active player; if using a three-player final, agree on a separate final scoring rule before implementing it.

## Implementation checklist
- Import validated 500-question JSON asset; verify schema and avoid duplicate draws per match.
- Add bilingual card UI, secret vote, reveal, reaction button, penalties, and match result.
- Connect to existing multiplayer room lifecycle without breaking other games.
- Handle reconnects, disconnects, voting timeout, reaction deadline and server idempotency.
- Add offline same-device pass-and-play without leaking hidden votes.
- Add server and Godot automated tests for 2–6 players and race/tie cases.
- Test on two Android phones before release.

No changes to main/production. This document is not a claim of end-to-end implementation.
