# GamingHub Multiplayer deployment

The repository contains a Render Blueprint and Docker build configuration.

**Deployment is blocked until the complete, tested `server/server.py` and `server/cards.json` from the GamingHub v7.4 source archive are uploaded.** Do not deploy an empty or placeholder server.

1. Upload those two files to the `server/` directory.
2. Connect this repository to Render and deploy the Blueprint in `render.yaml`.
3. Confirm `https://<service>.onrender.com/health` returns HTTP 200.
4. Confirm `wss://<service>.onrender.com` works using two actual WebSocket clients.
5. Set the verified WSS URL in the Godot client's `data/network_config.json`, build Android, and test on two devices.

Do not publish private player images, secrets, or API keys to this public repository.
