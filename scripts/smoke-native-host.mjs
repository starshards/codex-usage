import { spawn } from "node:child_process";

const child = spawn(".build/debug/CodexUsageNativeHost", [], { stdio: ["pipe", "pipe", "inherit"] });
const payload = Buffer.from(JSON.stringify({ type: "get_status", requestId: "smoke" }));
const length = Buffer.alloc(4);
length.writeUInt32LE(payload.length);
child.stdin.write(Buffer.concat([length, payload]));
child.stdin.end();

const chunks = [];
child.stdout.on("data", chunk => chunks.push(chunk));
child.on("close", code => {
  const output = Buffer.concat(chunks);
  if (output.length < 4) process.exit(1);
  const size = output.readUInt32LE(0);
  const message = JSON.parse(output.subarray(4, 4 + size).toString("utf8"));
  if (message.type !== "status") process.exit(1);
  console.log(JSON.stringify(message, null, 2));
  process.exit(code);
});
