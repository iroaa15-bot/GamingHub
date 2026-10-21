// No deployment, CI or paid infrastructure. Both backends bind loopback unless
// the operator explicitly supplies --lan for phones on the same private Wi-Fi.
import { spawn } from "node:child_process";
import { once } from "node:events";
import { startGameGateway } from "./game-gateway.mjs";

const port = Number(process.env.COLYSEUS_GATEWAY_PORT || 2568);
const backendPort = Number(process.env.GAMINGHUB_LOCAL_PORT || 8765);
const host = process.argv.includes("--lan") ? "0.0.0.0" : "127.0.0.1";
const backend = spawn(process.env.PYTHON || "python", ["-u", "server.py"], {
  cwd: new URL("../../server/", import.meta.url),
  env: { ...process.env, HOST: "127.0.0.1", PORT: String(backendPort) },
  stdio: ["ignore", "pipe", "inherit"] });
let gateway, stopping = false;
async function close() {
  if (stopping) return;
  stopping = true;
  await gateway?.close(); backend.kill("SIGTERM");
}
process.on("SIGINT", close); process.on("SIGTERM", close);
try {
  await Promise.race([
    once(backend.stdout, "data"),
    once(backend, "exit").then(() => { throw new Error("Local Python backend exited"); }),
    new Promise((_, reject) => setTimeout(() => reject(new Error("Python startup timed out")), 10_000).unref())
  ]);
  gateway = await startGameGateway({ backendUrl: `ws://127.0.0.1:${backendPort}`, host, port });
  console.log(`COLYSEUS_GATEWAY_READY ws://${host}:${gateway.port}/gaminghub`);
  console.log("Use this computer's LAN IP in the test APK's existing advanced connection settings.");
  backend.once("exit", () => { if (!stopping) { process.exitCode = 1; close(); } });
} catch (error) { console.error(error.message); process.exitCode = 1; await close(); }
