import { Server, Room } from "colyseus";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import { validInviteCode } from "./invite-code.mjs";

export class PartyRoom extends Room {
  maxClients = 6;
  onCreate(options) {
    if (typeof options.inviteCode !== "string" || options.inviteCode.length < 12) {
      throw new Error("inviteCode must have at least 12 characters");
    }
    this.inviteCode = options.inviteCode;
    this.autoDispose = true;
    this.onMessage("ping", (client, data) => client.send("pong", { nonce: data?.nonce ?? null }));
  }
  onAuth(client, options) {
    return validInviteCode(this.inviteCode, options?.inviteCode);
  }
  onJoin(client) { this.broadcast("member_joined", { sessionId: client.sessionId }); }
  onLeave(client) { this.broadcast("member_left", { sessionId: client.sessionId }); }
}
export async function startServer(port = 2567) {
  const httpServer = createServer();
  const gameServer = new Server({ server: httpServer });
  gameServer.define("party_poc", PartyRoom);
  await gameServer.listen(port, "127.0.0.1");
  return { gameServer, httpServer, port };
}
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  startServer(Number(process.env.PORT || 2567)).then(({port}) =>
    console.log(`POC server on 127.0.0.1:${port} (local only)`));
}
