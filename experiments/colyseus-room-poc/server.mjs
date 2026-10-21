import { Server, Room } from "colyseus";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import { validInviteCode } from "./invite-code.mjs";
import { MAX_PLAYERS, canJoinRoom, registerMember, unregisterMember } from "./room-policy.mjs";

export { validInviteCode } from "./invite-code.mjs";

export class PartyRoom extends Room {
  maxClients = MAX_PLAYERS;
  members = new Set();

  onCreate(options) {
    if (typeof options?.inviteCode !== "string" ||
        Buffer.byteLength(options.inviteCode, "utf8") < 12) {
      throw new Error("inviteCode must contain at least 12 UTF-8 bytes");
    }
    this.inviteCode = options.inviteCode;
    this.autoDispose = true;
    this.onMessage("ping", (client, data) =>
      client.send("pong", { nonce: data?.nonce ?? null }));
  }

  onAuth(client, options) {
    const inviteValid = validInviteCode(this.inviteCode, options?.inviteCode);
    return canJoinRoom({
      members: this.members,
      sessionId: client.sessionId,
      inviteValid,
    });
  }

  onJoin(client) {
    if (!registerMember(this.members, client.sessionId, true)) {
      throw new Error("room capacity exceeded");
    }
    this.broadcast("member_joined", { sessionId: client.sessionId });
  }

  async onLeave(client, consented) {
    // Colyseus owns the reconnection token. Do not accept a client-supplied
    // sessionId as proof of ownership. Only unexpected disconnects get a grace period.
    if (!consented) {
      try {
        await this.allowReconnection(client, 90);
        return; // Keep the member seat while Colyseus restores the connection.
      } catch {
        // Token expired or reconnection failed: release the seat below.
      }
    }
    unregisterMember(this.members, client.sessionId);
    this.broadcast("member_left", { sessionId: client.sessionId });
  }
}

export async function startServer(port = 2567) {
  const httpServer = createServer();
  const gameServer = new Server({ server: httpServer });
  gameServer.define("party_poc", PartyRoom);
  await gameServer.listen(port, "127.0.0.1");
  return { gameServer, httpServer, port };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  startServer(Number(process.env.PORT || 2567)).then(({ port }) =>
    console.log(`POC server on 127.0.0.1:${port} (local only)`));
}
