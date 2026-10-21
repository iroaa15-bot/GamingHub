import { createRequire } from "node:module";
import { existsSync } from "node:fs";
import { resolve } from "node:path";

const require = createRequire(import.meta.url);
const packages = ["colyseus", "@colyseus/sdk", "@colyseus/schema"];
let missing = 0;

for (const name of packages) {
  try {
    const entry = require.resolve(name);
    console.log("READY", name, entry);
  } catch (error) {
    if (error.code !== "MODULE_NOT_FOUND" && error.code !== "ERR_PACKAGE_PATH_NOT_EXPORTED") {
      console.error("ERROR", name, error.message);
    } else {
      console.error("MISSING", name);
    }
    missing++;
  }
}

if (!existsSync(resolve("server.mjs"))) {
  console.error("Run this command from experiments/colyseus-room-poc");
  process.exitCode = 1;
} else if (missing) {
  console.error(`Cannot run real integration tests: ${missing} package(s) unresolved.`);
  console.error("After network access is restored: npm install --ignore-scripts");
  process.exitCode = 1;
} else {
  console.log("Dependencies resolved. Run npm test to attempt real integration tests.");
}
