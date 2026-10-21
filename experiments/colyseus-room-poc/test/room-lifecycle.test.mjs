import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

// Offline simulation: replaces the Colyseus runtime with a minimal stand-in.
// It tests PartyRoom hooks, NOT actual Colyseus compatibility or WebSocket traffic.
const source = await readFile(new URL("../server.mjs", import.meta.url), "utf8");
const fakeRoom = `class Room {
  broadcast() {}
  onMessage(type, callback) {
    this.handlers ??= new Map();
    this.handlers.set(type, callback);
  }
}`;
const rewritten = source
  .replace('import { Server, Room } from "colyseus";', fakeRoom + "\nconst Server = class {};")
  .replace('import { createServer } from "node:http";', "const createServer = () => ({});")
  .replace('import { fileURLToPath } from "node:url";', 'const fileURLToPath = () => "not-entry";')
  .replaceAll('from "./invite-code.mjs"', `from "${new URL("../invite-code.mjs", import.meta.url).href}"`)
  .replaceAll('from "./room-policy.mjs"', `from "${new URL("../room-policy.mjs", import.meta.url).href}"`)
  .replace('export { validInviteCode } from "./invite-code.mjs";', "");
const { PartyRoom } = await import(`data:text/javascript,${encodeURIComponent(rewritten)}`);
const makeRoom = () => {
  const room = new PartyRoom();
  room.onCreate({ inviteCode: "local-secret-1234" });
  return room;
};
const client = sessionId => ({
  sessionId, sent: [],
  send(type, data) { this.sent.push([type, data]); }
});
test("invalid invitation denied in room hook", () => {
  const room = makeRoom();
  assert.equal(room.onAuth(client("a"), { inviteCode: "incorrect-secret" }), false);
  assert.equal(room.members.size, 0);
});
test("six players accepted, seventh denied, explicit leave frees slot", async () => {
  const room = makeRoom();
  for (let i = 0; i < 6; i++) {
    const c = client(`p${i}`);
    assert.equal(room.onAuth(c, { inviteCode: "local-secret-1234" }), true);
    room.onJoin(c);
  }
  assert.equal(room.members.size, 6);
  assert.equal(room.onAuth(client("p6"), { inviteCode: "local-secret-1234" }), false);
  await room.onLeave(client("p0"), true);
  assert.equal(room.onAuth(client("p6"), { inviteCode: "local-secret-1234" }), true);
});
test("ping message triggers pong", () => {
  const room = makeRoom();
  const c = client("a");
  room.handlers.get("ping")(c, { nonce: "x" });
  assert.deepEqual(c.sent, [["pong", { nonce: "x" }]]);
});

test("unexpected disconnect reserves seat until Colyseus rejects reconnect", async () => {
  const room = makeRoom();
  const c = client("p0");
  room.onJoin(c);
  let resolveReconnect;
  room.allowReconnection = () => new Promise(resolve => { resolveReconnect = resolve; });
  const leaving = room.onLeave(c, false);
  assert.equal(room.members.has("p0"), true);
  resolveReconnect();
  await leaving;
  assert.equal(room.members.has("p0"), true);
});
test("expired reconnect releases seat", async () => {
  const room = makeRoom();
  const c = client("p0");
  room.onJoin(c);
  room.allowReconnection = async () => { throw new Error("expired"); };
  await room.onLeave(c, false);
  assert.equal(room.members.has("p0"), false);
});
