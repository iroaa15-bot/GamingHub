# Gaming Hub — Consolidated release readiness audit (2026-11-08)

## Inventory
- 10 core games in `scripts/main.gd` constant `GAMES`.
- 6 standalone social games linked from `show_more_games()`.
- **16 distinct game entries**. Arcade modes, daily challenges, and multiplayer variants are not counted as separate games.
- Social content: 3000 card records targeted across six categories; **not an editorial PASS**.

## Evidence and release status
- Feature branch `feature/qaadet-el-sohab-content-20261105` is **171 commits ahead of main** as observed on 2026-11-08. Do not merge without explicit approval.
- Static source inspection shows social offline entry points and test scripts, but **no verified Godot headless run, device run, signed APK or AAB**.
- Social `standalone_social_games.gd` explicitly disables online Friends Rooms. `server/party_rooms.py` is a prototype, not proof of integration into production WebSocket.
- `main.gd` currently opens a home screen with many controls, **not** the requested Guest / Google / Facebook-only login entry screen.
- No confirmed Google or Facebook OAuth provider configuration, durable account sessions, or live login acceptance test.
- No evidence here that Android 9 button crash, two-device voice chat, microphone permission, reconnection, or image/sound asset completeness have passed.
- No verified Google Play signing key, release AAB, Play policy checks, or closed testing sign-off.

## Release blockers (must be closed together, not described as complete)
1. Run `tools/run_social_tests.ps1` with Godot 4.5.1, repair parse/runtime failures; run game UI smoke on Android 9 and another physical phone.
2. Run `tools/audit_qaadet_el_sohab.py`; remove exact and semantic repetition; manually review the 3000 generated cards for natural Arabic, entertainment value, and safe content.
3. Integrate social room actions into authenticated production multiplayer protocol: authoritative player identity, permissions, turn ownership, vote secrecy, timer, reconnect, and server scoring; add two-device tests.
4. Implement and validate social match persistence and account score updates, including guest upgrade and login recovery.
5. Implement requested login UX: full-screen image, only Guest / Google / Facebook buttons with official logos; language globe enlarged; larger player avatars/names.
6. Validate OAuth configurations and real Google/Facebook sign-in; test guest and account data privacy.
7. Resolve all Android crashes, voice AEC/NS/AGC, permissions, reconnect, and touch/scroll behavior; test on two real phones.
8. Validate legacy games, 200 guess-picture assets, sound bank, 3000 original quiz questions, cinema challenge improvements, and all content licenses.
9. Complete Android release pipeline, signed AAB, upload key, versioning, Play Data Safety/ads/child protections, privacy policy, internal/closed tests.
10. After PASS evidence and explicit user approval only, integrate to main and publish.

## Release decision
**NO-GO for Google Play.** The feature branch is useful development work, not a verified production build. A numerical readiness percentage would be invented without test results.

## What constitutes completion
Attach test output, content audit report, 2-device test logs, signed AAB SHA-256, successful Google/Facebook login evidence, and a release checklist signed off before changing production.
