import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

test("registers native host for multiple extension ids and Chrome directories", () => {
  const root = path.resolve(".");
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "codex-usage-native-host-"));
  const targetA = path.join(temp, "Google Chrome", "NativeMessagingHosts");
  const targetB = path.join(temp, "Chromium", "NativeMessagingHosts");
  const hostBinary = path.join(root, ".build", "debug", "CodexUsageNativeHost");

  const result = spawnSync(
    "bash",
    ["scripts/register-native-host.sh", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"],
    {
      cwd: root,
      env: {
        ...process.env,
        CODEX_USAGE_SKIP_SWIFT_BUILD: "1",
        CODEX_USAGE_HOST_BINARY: hostBinary,
        CODEX_USAGE_NATIVE_HOST_DIRS: `${targetA}:${targetB}`
      },
      encoding: "utf8"
    }
  );

  assert.equal(result.status, 0, result.stderr || result.stdout);

  for (const target of [targetA, targetB]) {
    const manifestPath = path.join(target, "com.starshards.codex_usage.json");
    const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

    assert.equal(manifest.name, "com.starshards.codex_usage");
    assert.equal(manifest.path, hostBinary);
    assert.deepEqual(manifest.allowed_origins, [
      "chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/",
      "chrome-extension://bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/"
    ]);
  }
});
