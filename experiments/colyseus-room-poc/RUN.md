# Gaming Hub — isolated Colyseus experiment

**Experimental only.** This directory is not wired to the Android app, production server, or `main`. Do not deploy publicly. Node.js 20+ is required.

## Run dependency-free checks

```sh
cd experiments/colyseus-room-poc
npm run test:offline
node --check server.mjs
```

These tests use a mock Room for lifecycle hooks. They do **not** prove that Colyseus, WebSocket, reconnection, or voice works.

## Run actual network integration (requires network access)

```sh
cd experiments/colyseus-room-poc
npm install --ignore-scripts
npm run preflight
npm test
```

If `npm install` fails with `EAI_AGAIN`, dependency download is blocked by DNS/network connectivity. Stop there; do not claim a successful network test. Do not trigger GitHub Actions as a workaround.

`npm test` includes tests that start a **loopback-only** server at `127.0.0.1`, exercise joining, invite rejection, capacity, ping/pong, and a reconnection attempt. They have not been validated against an installed Colyseus runtime yet. Fix any real integration failures before Android integration.

## Safety / scope

- Keep `main`, the existing Gaming Hub APK, production services, daily content generator, and other projects unchanged.
- No paid services or CI builds.
- Do not expose the example static invite code or the loopback server to the internet.
- Reconnection must be authorized using Colyseus' own reconnection token, not an arbitrary session ID.
- Voice/echo/low-volume on two physical Android phones remains a **separate, unverified** acceptance test.
- Build an isolated test APK only after the network integration suite passes.
