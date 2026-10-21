import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { once } from "node:events";
import { WebSocket } from "ws";
import { startGameGateway } from "../game-gateway.mjs";

async function freePort() {
  const server = createServer(); server.listen(0, "127.0.0.1"); await once(server, "listening");
  const port = server.address().port; await new Promise(resolve => server.close(resolve)); return port;
}
async function setup() {
  const port = await freePort();
  const backend = spawn(process.env.PYTHON || "python", ["-u", "server.py"], {
    cwd: new URL("../../../server/", import.meta.url),
    env: { ...process.env, HOST: "127.0.0.1", PORT: String(port) }, stdio: ["ignore", "pipe", "pipe"] });
  let errors = ""; backend.stderr.on("data", bytes => errors += bytes);
  await Promise.race([
    once(backend.stdout, "data"),
    once(backend, "exit").then(() => { throw new Error("Python backend failed: " + errors); }),
    new Promise((_, reject) => setTimeout(() => reject(new Error("Python startup timeout")), 5000).unref())
  ]);
  const gateway = await startGameGateway({ backendUrl: `ws://127.0.0.1:${port}` });
  const clients = [];
  async function phone() {
    const ws = new WebSocket(`ws://127.0.0.1:${gateway.port}/gaminghub`);
    const inbox = [], waiters = [];
    ws.on("message", bytes => {
      inbox.push(JSON.parse(bytes.toString()));
      for (const notify of waiters.splice(0)) notify();
    });
    await once(ws, "open"); clients.push(ws);
    return { ws, send: data => ws.send(JSON.stringify(data)), async next(type) {
      const deadline = Date.now() + 6000;
      while (Date.now() < deadline) {
        const index = inbox.findIndex(p => p.type === type);
        if (index >= 0) return inbox.splice(index, 1)[0];
        const error = inbox.find(p => p.type === "error");
        if (error && type !== "error") throw new Error(JSON.stringify(error));
        await new Promise(resolve => {
          const timer = setTimeout(resolve, 100);
          waiters.push(() => { clearTimeout(timer); resolve(); });
        });
      }
      throw new Error("Missing " + type + ": " + JSON.stringify(inbox));
    } };
  }
  return { phone, port: gateway.port, async close() {
    clients.forEach(ws => ws.terminate()); await gateway.close();
    backend.kill("SIGTERM"); await once(backend, "exit");
  } };
}

test("real Godot JSON protocol crosses Colyseus: game, capacity, reconnect, voice isolation", { timeout: 25000 }, async () => {
  const app = await setup();
  try {
    const a = await app.phone(), b = await app.phone(), stranger = await app.phone();
    a.send({ type: "create" }); const room = await a.next("room");
    stranger.send({ type: "join", code: "XXXXXX" }); await stranger.next("error");
    b.send({ type: "join", code: room.code }); await b.next("room");
    const sa = await a.next("started"), sb = await b.next("started");
    assert.equal(sa.player_index, 0); assert.equal(sb.player_index, 1);
    assert.equal(sa.opponent_card.name.length > 0, true);
    assert.equal(sa.my_card, undefined, "Secret card must stay on Python server");
    stranger.send({ type: "join", code: room.code }); await stranger.next("error");
    a.send({ type: "ask", question: 0 }); await a.next("question"); await b.next("question");
    await a.next("turn"); await b.next("turn");
    a.ws.terminate(); await b.next("paused");
    const recovered = await app.phone();
    recovered.send({ type: "resume", code: room.code, token: sa.resume_token });
    const resumed = await recovered.next("resumed");
    assert.equal(resumed.player_index, sa.player_index);
    assert.equal(resumed.moves, 1); assert.equal(resumed.history.length, 1);
    assert.notEqual(resumed.resume_token, sa.resume_token);
    stranger.send({ type: "resume", code: room.code, token: sa.resume_token }); await stranger.next("error");
    recovered.send({ type: "voice_state", enabled: true, request_id: 1 });
    await recovered.next("voice_state_ack"); await b.next("voice_state");
    b.send({ type: "voice_state", enabled: true, request_id: 1 });
    const consent = await b.next("voice_state_ack"); await recovered.next("voice_state");
    recovered.send({ type: "voice_offer", payload: { epoch: consent.epoch, sdp: "v=0\r\n" } });
    assert.equal((await b.next("voice_offer")).payload.sdp, "v=0\r\n");
    b.send({ type: "voice_answer", payload: { epoch: consent.epoch, sdp: "v=0\r\n" } });
    await recovered.next("voice_answer");
    recovered.send({ type: "voice_ice", payload: { candidate: 7 } });
    assert.equal((await recovered.next("error")).scope, "voice");
    recovered.send({ type: "ping", id: 501 }); assert.equal((await recovered.next("pong")).id, 501);
    // Authoritative next turn remains playable after the isolated voice failure.
    b.send({ type: "ask", question: 1 }); await b.next("question"); await recovered.next("question");
    recovered.send({ type: "leave" }); await recovered.next("left"); await b.next("disconnected");
    b.send({ type: "matchmake" }); const nextMatch = await b.next("room");
    assert.notEqual(nextMatch.code, room.code);
  } finally { await app.close(); }
});

test("real Colyseus random matchmaking pairs two players and separates the third", { timeout: 20000 }, async () => {
  const app = await setup();
  try {
    const a = await app.phone(), b = await app.phone(), c = await app.phone();
    a.send({ type: "matchmake" }); const first = await a.next("room");
    b.send({ type: "matchmake" }); const second = await b.next("room");
    assert.equal(first.code, second.code); await a.next("started"); await b.next("started");
    c.send({ type: "matchmake" }); const third = await c.next("room");
    assert.notEqual(first.code, third.code);
    c.send({ type: "cancel_queue" }); await c.next("left");
    // Same WebSocket can request a fresh game after cancellation.
    c.send({ type: "create" }); const fresh = await c.next("room");
    assert.notEqual(fresh.code, third.code);
  } finally { await app.close(); }
});
