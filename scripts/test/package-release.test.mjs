import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

const root = new URL("../..", import.meta.url);

test("release packaging help documents signing, notarization, and GitHub Releases", () => {
  const result = spawnSync("bash", ["scripts/package-release.sh", "--help"], {
    cwd: root,
    encoding: "utf8"
  });

  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /CODEX_USAGE_SIGN_IDENTITY/);
  assert.match(result.stdout, /CODEX_USAGE_NOTARY_PROFILE/);
  assert.match(result.stdout, /gh release create/);
});

test("release packaging dry run prints the signed dmg and zip workflow", () => {
  const result = spawnSync(
    "bash",
    [
      "scripts/package-release.sh",
      "--dry-run",
      "--version",
      "1.2.3",
      "--sign-identity",
      "Developer ID Application: Example (ABCDE12345)",
      "--notary-profile",
      "codex-usage-notary",
      "--notarize"
    ],
    {
      cwd: root,
      encoding: "utf8"
    }
  );

  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /swift build -c release --product CodexUsageMenubar/);
  assert.match(result.stdout, /codesign .*Developer ID Application: Example/);
  assert.match(result.stdout, /xcrun notarytool submit .*--keychain-profile codex-usage-notary --wait/);
  assert.match(result.stdout, /Codex Usage-1\.2\.3\.dmg/);
  assert.match(result.stdout, /Codex Usage-1\.2\.3\.zip/);
  assert.match(result.stdout, /gh release create v1\.2\.3/);
});
