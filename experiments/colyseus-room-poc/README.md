# Gaming Hub — isolated Colyseus Android experiment

Branch: `experiment/colyseus-room-poc`. No production deployment or CI is required.

The original `party_poc` six-seat room is exercised using real Colyseus clients.
`game-gateway.mjs` connects the existing Godot JSON/WebSocket protocol to Colyseus
private/public two-seat rooms using the official `colyseus.js` 0.16 SDK. Python
continues to own game rules, cards, turn validation, history and voice consent.
This is an opt-in transport experiment, not a replacement for the existing backend.

## Verified locally

- Actual SDK/WebSocket joins, invitations, six-seat capacity and replacement.
- Authenticated Colyseus reconnection; Python snapshot/token rotation and moves survive.
- Private room codes, public two-player matchmaking, full-room rejection, cancellation and a new game.
- Actual `multiplayer.gd` clients through the gateway; JNI is simulated in this test.
- Real aiortc Opus/SRTP loopback UDP: 1500 non-silent frames each direction.
- A 501-ICE burst does not block heartbeat or a real game move.

The detailed results and Android limitations are in
[the Arabic recovery report](../../docs/colyseus-recovery/REPORT_AR.md).

## Cost and isolation

Use Node.js 20+ and Python 3.10+. Install the pinned lockfile with `npm ci --ignore-scripts`.
`@colyseus/sdk@0.16` does not exist; 0.16 clients use `colyseus.js`.
Only core, schema, WebSocket transport, SDK and ws are installed; Redis/auth/native
transports and paid hosting are not needed. The gateway refuses non-loopback Python backends.

`npm audit --omit=dev` still reports the legacy core's transitive `nanoid` advisory.
Do not expose this POC publicly. The direct `ws` dependency is updated to 8.22.0.
A migration to a maintained Colyseus generation requires its own compatibility gate;
do not silence audit or force an incompatible nanoid major override.

Colyseus manages membership/signaling transport; Android voice uses native libwebrtc.
No physical Android microphone/speaker, echo, loudness, packet loss, mobile NAT/TURN
or OPPO A31 success is claimed. Rooms/tokens are in memory and do not survive server restart.
