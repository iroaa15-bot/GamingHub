// Opt-in JSON/WebSocket boundary for the existing Godot client. Colyseus owns
// matchmaking, seats and reconnect tokens; Python remains authoritative for rules.
import { Server, Room } from "@colyseus/core";
import { WebSocketTransport } from "@colyseus/ws-transport";
import { Client } from "colyseus.js";
import { WebSocket, WebSocketServer } from "ws";
import { createServer } from "node:http";
import { setTimeout as delay } from "node:timers/promises";

const allowed = new Set(["ping", "sync", "ask", "guess", "leave", "voice_state",
  "voice_offer", "voice_answer", "voice_ice", "voice_ice_config", "voice_audio"]);
const errorPacket = message => ({ type: "error", message });

export async function startGameGateway({ backendUrl, port = 0, host = "127.0.0.1" } = {}) {
  const target = new URL(backendUrl);
  if (target.protocol !== "ws:" || !["127.0.0.1", "localhost", "[::1]"].includes(target.hostname)) {
    throw new Error("Experimental gateway requires a loopback Python backend");
  }
  const codes = new Map();
  const credentials = new Map();
  const internal = createServer();
  class GameRoom extends Room {
    maxClients = 2;
    links = new Map();
    code = "";
    async onCreate(options) {
      this.mode = options.mode;
      this.codeReady = new Promise(resolve => { this.setCode = resolve; });
      this.onMessage("game", (client, packet) => {
        // Serialize per player so an ICE callback cannot overtake its consent.
        const link = this.links.get(client.sessionId);
        if (!link) return;
        link.queue = link.queue.then(async () => {
          await link.ready;
          if (packet?.type === "begin") {
            if (link.begun) return;
            link.begun = true;
            if (!this.creator) {
              this.creator = client.sessionId;
              link.ws.send(JSON.stringify({ type: "create" }));
            } else {
              const code = await this.codeReady;
              link.ws.send(JSON.stringify({ type: "join", code }));
            }
          } else if (packet?.type === "resume" || allowed.has(packet?.type)) {
            link.ws.send(JSON.stringify(packet));
          } else {
            client.send("event", errorPacket("Unsupported action"));
          }
        }).catch(() => client.send("event", errorPacket("Local game backend unavailable")));
      });
    }
    openLink(client) {
      const ws = new WebSocket(backendUrl, { maxPayload: 32768, perMessageDeflate: false });
      const link = { ws, queue: Promise.resolve(), begun: false };
      link.ready = new Promise((resolve, reject) => {
        ws.once("open", resolve);
        ws.once("error", reject);
        ws.once("close", () => reject(new Error("Backend closed")));
      });
      link.ready.catch(() => {});
      ws.on("message", bytes => {
        const packet = JSON.parse(bytes.toString());
        if (packet.type === "room") {
          this.code = packet.code; codes.set(this.code, this.roomId); this.setCode(this.code);
        }
        client.send("event", packet);
      });
      ws.on("error", () => client.send("event", errorPacket("Local game backend unavailable")));
      this.links.set(client.sessionId, link);
    }
    onJoin(client) {
      this.openLink(client);
      // A started match must never become a fresh matchmaking candidate on leave.
      if (this.clients.length === 2) this.lock();
    }
    async onLeave(client, consented) {
      const link = this.links.get(client.sessionId);
      this.links.delete(client.sessionId);
      if (link) { link.ws.on("error", () => {}); link.ws.close(); }
      if (!consented) {
        try {
          const recovered = await this.allowReconnection(client, 90);
          this.openLink(recovered);
          return;
        } catch { /* Seat expires; Python also expires its game reservation. */ }
      }
    }
    onDispose() {
      codes.delete(this.code);
      for (const [token, entry] of credentials) if (entry.roomId === this.roomId) credentials.delete(token);
      for (const link of this.links.values()) link.ws.close();
    }
  }
  const gameServer = new Server({ transport: new WebSocketTransport({ server: internal }),
    greet: false, gracefullyShutdown: false });
  gameServer.define("gaminghub_private", GameRoom);
  gameServer.define("gaminghub_public", GameRoom);
  await gameServer.listen(0, "127.0.0.1");
  const sdk = new Client(`ws://127.0.0.1:${internal.address().port}`);
  const http = createServer((req, res) => {
    res.writeHead(req.url === "/health" ? 200 : 404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok", backend: "colyseus-local", production: false }));
  });
  const sockets = new WebSocketServer({ server: http, path: "/gaminghub", maxPayload: 32768,
    perMessageDeflate: false });
  sockets.on("connection", socket => {
    socket.alive = true;
    socket.on("pong", () => { socket.alive = true; });
    let room, currentToken, leaveAck, closed = false, queue = Promise.resolve();
    const send = packet => {
      if (socket.readyState !== WebSocket.OPEN) return;
      if (socket.bufferedAmount > 131072) { socket.close(1013, "Slow client"); return; }
      socket.send(JSON.stringify(packet));
    };
    const attach = value => {
      room = value;
      value.onMessage("event", packet => {
        if (packet.resume_token) {
          if (currentToken) credentials.delete(currentToken);
          currentToken = packet.resume_token;
          credentials.set(currentToken, { token: value.reconnectionToken, roomId: value.roomId,
            expires: Date.now() + 90_000, active: true });
        }
        if (packet.type === "left") {
          if (currentToken) credentials.delete(currentToken);
          leaveAck?.();
        }
        send(packet);
        if (packet.type === "disconnected") {
          if (currentToken) credentials.delete(currentToken);
          if (room === value) room = undefined;
          value.leave().catch(() => {});
        }
      });
      room.onError((_code, message) => send(errorPacket(message)));
      value.onLeave(() => { if (room === value && !closed) socket.close(1011, "Room transport lost"); });
      if (closed) room.connection.close();
    };
    socket.on("message", bytes => {
      let scope;
      queue = queue.then(async () => {
        if (closed) return;
        const packet = JSON.parse(bytes.toString());
        scope = packet?.type === "resume" ? "resume" : packet?.type?.startsWith("voice_") ? "voice" : undefined;
        if (!packet || typeof packet.type !== "string") throw new Error("Invalid action");
        if (packet.type === "ping" && !room) { send({ type: "pong", id: packet.id }); return; }
        if (["create", "join", "matchmake"].includes(packet.type)) {
          if (room) throw new Error("Already in a room");
          if (packet.type === "join") {
            const id = codes.get(packet.code);
            if (!id) throw new Error("Room not found");
            attach(await sdk.joinById(id));
          } else if (packet.type === "create") {
            attach(await sdk.create("gaminghub_private", { mode: "private" }));
          } else {
            attach(await sdk.joinOrCreate("gaminghub_public", { mode: "public" }));
          }
          room.send("game", { type: "begin" });
        } else if (packet.type === "resume") {
          if (room) throw new Error("Already in a room");
          const saved = credentials.get(packet.token);
          if (!saved || (!saved.active && saved.expires <= Date.now())) throw new Error("Invalid resume credentials");
          if (saved.active) throw new Error("Original player still connected");
          let recovered;
          // Close notification, Colyseus reservation and Python detach are asynchronous.
          for (let attempt = 0; attempt < 20; attempt++) {
            try { recovered = await sdk.reconnect(saved.token); break; }
            catch (error) { if (error.code !== 4214 || attempt === 19) throw error; await delay(50); }
          }
          attach(recovered);
          room.send("game", packet);
        } else if (["leave", "cancel_queue"].includes(packet.type)) {
          if (room) {
            // Leave the authoritative match before releasing Colyseus membership.
            const previous = room;
            let timer;
            const ack = new Promise((resolve, reject) => {
              leaveAck = resolve;
              timer = setTimeout(() => reject(new Error("Leave acknowledgement timeout")), 3000);
            });
            previous.send("game", { type: "leave" });
            try { await ack; } finally {
              clearTimeout(timer); leaveAck = undefined; room = undefined;
              await previous.leave();
            }
          } else send({ type: "left" });
          if (currentToken) credentials.delete(currentToken);
        } else if (room) room.send("game", packet);
        else throw new Error("No active match");
      }).catch(error => send({ ...errorPacket(error.message), ...(scope ? { scope } : {}) }));
    });
    socket.on("error", () => {});
    socket.on("close", () => {
      closed = true;
      const saved = credentials.get(currentToken);
      if (saved) { saved.active = false; saved.expires = Date.now() + 90_000; }
      if (room) room.connection.close(); // Abrupt loss reserves the same Colyseus seat.
    });
  });
  const cleanup = setInterval(() => {
    for (const [token, saved] of credentials) if (!saved.active && saved.expires <= Date.now()) credentials.delete(token);
  }, 30_000);
  cleanup.unref();
  const heartbeat = setInterval(() => {
    for (const socket of sockets.clients) {
      if (!socket.alive) socket.terminate();
      else { socket.alive = false; socket.ping(); }
    }
  }, 10_000);
  heartbeat.unref();
  await new Promise(resolve => http.listen(port, host, resolve));
  return { port: http.address().port, gameServer, async close() {
    clearInterval(cleanup); clearInterval(heartbeat);
    for (const socket of sockets.clients) socket.terminate();
    await new Promise(resolve => sockets.close(resolve));
    await new Promise(resolve => http.close(resolve));
    await gameServer.gracefullyShutdown(false);
  } };
}
