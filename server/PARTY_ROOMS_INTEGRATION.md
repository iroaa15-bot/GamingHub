# Party-room integration contract (draft)

The production `server/server.py` remains unchanged. `party_rooms.py` is a standalone Python authoritative state-machine prototype, **not** a live WebSocket endpoint.

## Required gateway (not implemented)
- Authenticate a socket to an opaque per-room player identity. Never trust a player ID supplied by the client.
- Host-only room creation/start, max 6 connected players; server controls draw, round completion and timeout.
- Route `party_create`, `party_join`, `party_start`, `party_vote`, `party_story_commit`, `party_sync` only after authentication and input-size limits.
- Broadcast `public_state(viewer)` to members only; never send `story_truth` or individual votes before reveal.
- Use an asyncio lock per room to serialize votes and resolution; rate-limit actions and expire stale rooms.
- Restore room membership with rotated resume tokens and enforce the reconnect window.
- Do not reuse the existing two-player Guess Picture room state or its resume tokens.
- Only the server chooses the card and resolves the round; do not accept arbitrary points from clients.
- Apply all power effects server-side after dedicated tests; currently **not supported** by the Python party room.
- Reconcile vote eligibility in 2-player rooms and specify a consistent tie policy.
- Decide whether power cards consume a round; align Godot and Python rules before any release.

## Manual test commands when Python is available
`cd server && python -m unittest test_party_rooms -v`

The test file was committed but has not been executed in this environment. No Android or remote multiplayer testing has been performed. Do not merge until authenticated multi-client end-to-end tests pass.
