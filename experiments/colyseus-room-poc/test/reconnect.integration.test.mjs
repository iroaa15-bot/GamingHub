import test from "node:test";
import assert from "node:assert/strict";
import { Client } from "colyseus.js";
import { startServer } from "../server.mjs";

// Real network test. Requires installed Colyseus packages.
// Intentionally excluded from the dependency-free offline suite.
test("unexpected socket loss restores the same session within 90 seconds", { timeout: 20_000 }, async () => {
  const port = 29000 + Math.floor(Math.random() * 1000);
  const { gameServer } = await startServer(port);
  const client = new Client(`ws://127.0.0.1:${port}`);
  let room, recovered;
  try {
    room = await client.create("party_poc", { inviteCode: "local-secret-1234" });
    const roomId = room.roomId;
    const sessionId = room.sessionId;
    const token = room.reconnectionToken;
    assert.ok(typeof token === "string" && token.length > 0, "SDK must expose a reconnect token");

    // Abrupt transport loss, not room.leave() (which means intentional exit).
    const dropped = new Promise(resolve => room.onLeave(resolve));
    room.connection.close();
    await dropped;
    // The local close callback can race the server registering its reservation.
    // Retry only the reconnection token, never a game move or arbitrary session ID.
    for (let attempt = 0; attempt < 10; attempt++) {
      try { recovered = await client.reconnect(token); break; }
      catch (error) {
        if (error.code !== 4214 || attempt === 9) throw error;
        await new Promise(resolve => setTimeout(resolve, 50));
      }
    }
    assert.equal(recovered.roomId, roomId);
    assert.equal(recovered.sessionId, sessionId);

    const pong = new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("reconnected ping timed out")), 3_000);
      recovered.onMessage("pong", message => { clearTimeout(timer); resolve(message); });
    });
    recovered.send("ping", { nonce: "after-reconnect" });
    assert.equal((await pong).nonce, "after-reconnect");
  } finally {
    await Promise.allSettled([recovered?.leave()]);
    await gameServer.gracefullyShutdown(false);
  }
});
