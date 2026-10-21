import { Server, Room, matchMaker } from "colyseus";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";

export class PartyRoom extends Room {
  maxClients = 6;
  onCreate() {
    this.autoDispose = true;
    this.onMessage("ping", (client, data) => client.send("pong", { nonce: data?.nonce ?? null }));
  }
  onJoin(client) { this.broadcast("member_joined", { sessionId: client.sessionId }); }
  onLeave(client) { this.broadcast("member_left", { sessionId: client.sessionId }); }
}
export async function startServer(port = 2567) {
  const httpServer = createServer();
  const gameServer = new Server({ server: httpServer });
  gameServer.define("party_poc", PartyRoom).filterBy(["privateCode"]);
  await gameServer.listen(port, "127.0.0.1");
  return { gameServer, httpServer, port };
}
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  startServer(Number(process.env.PORT || 2567)).then(({port}) =>
    console.log(`POC server on 127.0.0.1:${port} (local only)`));
}
