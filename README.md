# Gaming Hub — Guess Your Picture

Godot multiplayer mini-game. In a match, each player sees the **opponent's** secret picture, never their own. Players ask yes/no questions and guess their own picture.

## Multiplayer server
- Source: `server/server.py`, `server/cards.json`
- Render dashboard: https://dashboard.render.com/web/srv-db6r5eou01pc73b91f90
- HTTP health: https://gaminghub-multiplayer.onrender.com/health
- WebSocket URL: `wss://gaminghub-multiplayer.onrender.com`
- Render plan: Free (can sleep when inactive).
- Automatic deploys from `main` are enabled.
- Deploy status was **live** on 2026-10-13. This is not equivalent to completed real-device testing.

## Godot client
The full Godot client, source assets, Poing AdMob v5.1.0 Android libraries and UMP bridge are now committed here. The multiplayer endpoint is configured in `data/network_config.json`.

Gaming Hub is an independent project. Android package: `com.iroaa15.gaminghub`. Version code 116, version name 11.6; target SDK 36.

Production ads remain disabled. Google test rewarded ads are limited to debug Android builds for adults after UMP resolves. Only the SDK earned callback grants 50 Coins; duplicate, stale and close callbacks grant nothing. Daily content is additive, newest first, with offline caches and history backfill.

## Validation
- Local regression suites: 198 game tests, 56 backend/client-contract tests, 3 illustrated-content tests passing.
- Godot 4.5.1 import and gameplay smoke: passing. Additional runtime test covers archive merging and reward/age/consent state gates with a simulated adapter.
- Remote two-client WSS room, question, turn, wrong guess and leave test: passing.
- Remote end-to-end test script: `server/test_live_match.py`.
- GitHub Actions remote test workflow: `.github/workflows/remote-multiplayer-smoke.yml`.
- Render history HTTP checks now pass: two newest-first pages, no page overlap, and historical image SHA-256 verified back to 1 October 2026. Multiplayer was retested successfully after the history endpoints became available. Render deployment metadata still reports an update in progress, so the GitHub head is not claimed as the running server revision.
- **Pending**: physical Android device and native advertising/UMP tests, authenticated Play Console review/submission, final privacy/developer-name review and genuine Android listing screenshots.

## Safety
Do not commit secrets, API keys, or private player photos.
