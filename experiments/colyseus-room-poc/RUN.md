# Local-only Colyseus experiment
Requires Node.js 20+.
```sh
cd experiments/colyseus-room-poc
npm install
npm test
npm start
```
No GitHub Actions, no production deployment, no main changes.
This POC tests a two-client room and ping only; it does **not** implement secure invite-code authorization, reconnect reservations, voice, or Android integration.
Room creation/join-by-ID in this demo is **not** secure access control. Do not expose this server publicly.
