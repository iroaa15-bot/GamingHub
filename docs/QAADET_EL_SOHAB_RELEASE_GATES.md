# قعدة الصحاب — Integration acceptance gates (8 November 2026)

## Existing assets
- Godot rules: scripts/qaadet_el_sohab_engine.gd
- Preview: scenes/QaadetElSohabPreview.tscn
- Content: content/qaadet_el_sohab/seed_ar.json and seed_ar_batch02.json
- Server prototypes: server/party_rooms.py, server/party_gateway.py, server/party_content.py
- Tests: tests/qaadet_el_sohab_rules_smoke.gd and server/test_party_rooms.py

## Mandatory release gates
1. Count and validate authored cards from BOTH seeds; never report 3,000 complete from a target alone. Preserve original cards and IDs, remove semantic duplicates, no math puzzles.
2. Fill six category targets: 500/550/550/550/550/300 = 3,000 original reviewed cards; Arabic and English localization verified.
3. Godot: one standalone game entry with exactly three actions: Friends, Offline, Back. Existing games remain available and unchanged.
4. Offline: 2–6 players, 10/15/20 rounds, unique card draws, secret handoff voting where applicable, correct category-specific mechanics, score and restart.
5. Online: use EXISTING Gaming Hub room/account infrastructure; server owns deck, score, timer, vote validation, power consumption and reconnect snapshot. Do not mistake party_gateway.py prototype for connected production WebSocket routing.
6. Validate table_flip power effects and expiration. Current engine explicitly does NOT apply power effects; this is a release blocker.
7. Add deterministic tests for each category, 2 and 6 players, ties, missing/disconnected votes, timeout, reconnection, duplicate actions, no repeated card and all power effects.
8. Test Godot headless, Android 9 and two physical phones; attach actual command output/logcat and build hash. No claim of PASS without execution.
9. Combine with Maana Wala Alayna (separate game, 3–6 players, 500 original cards), without overwriting its branch or content.
10. Draft PR(s), do not merge main, deploy, spend credits, or modify production without explicit approval.

## Known limitations
- Existing seed is NOT the full 3,000-card deliverable.
- Current local engine is a prototype; the table_flip category has no working power execution.
- Do not assume online rooms, Google/Facebook login, voice, Android build, or device tests are functional without evidence.
