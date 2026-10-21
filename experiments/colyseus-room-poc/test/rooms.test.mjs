import test from "node:test";
import assert from "node:assert/strict";
import { Client } from "@colyseus/sdk";
import { startServer, validInviteCode } from "../server.mjs";

test("invite code validator rejects incorrect and short codes", () => {
  assert.equal(validInviteCode("long-secret-1234", "long-secret-1234"), true);
  assert.equal(validInviteCode("long-secret-1234", "wrong-secret-123"), false);
  assert.equal(validInviteCode("short", "short"), false);
});
test("two players join; wrong invite code is rejected; ping works", async () => {
  const port = 27000 + Math.floor(Math.random() * 1000);
  const { gameServer } = await startServer(port);
  const client = new Client(`ws://127.0.0.1:${port}`);
  let room1, room2;
  try {
    room1 = await client.create("party_poc", { inviteCode: "local-secret-1234" });
    await assert.rejects(client.joinById(room1.roomId, { inviteCode: "incorrect-code-1" }));
    room2 = await client.joinById(room1.roomId, { inviteCode: "local-secret-1234" });
    assert.equal(room1.roomId, room2.roomId);
    assert.notEqual(room1.sessionId, room2.sessionId);
    assert.equal(room1.name, "party_poc");
    const pong = new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("pong timeout")), 3000);
      room2.onMessage("pong", message => { clearTimeout(timeout); resolve(message); });
    });
    room2.send("ping", { nonce: "test" });
    assert.equal((await pong).nonce, "test");
  } finally {
    await Promise.allSettled([room1?.leave(), room2?.leave()]);
    await gameServer.gracefullyShutdown();
  }
});
