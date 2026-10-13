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
The multiplayer endpoint is configured in `data/network_config.json`. The complete Godot game is distributed as a separate ZIP; it has not been committed in full to this repository.

## Validation
- Python server unit tests: 10/10 passing locally.
- Local two-client WebSocket integration: passing.
- Remote end-to-end test script: `server/test_live_match.py`.
- GitHub Actions remote test workflow: `.github/workflows/remote-multiplayer-smoke.yml`.
- **Pending**: confirmed remote WSS end-to-end result and two physical Android device tests.

## Safety
Do not commit secrets, API keys, or private player photos.
