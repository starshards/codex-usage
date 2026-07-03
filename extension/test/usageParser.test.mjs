import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { parseUsageSource } from "../src/usageParser.js";

test("parses redacted usage source fixture from top-level rate limit", () => {
  const expected = JSON.parse(fs.readFileSync("extension/fixtures/usage-expected-v1.json", "utf8"));
  const source = fs.readFileSync("extension/fixtures/usage-source-v1.redacted.json", "utf8");

  const parsed = parseUsageSource(source, {
    timeZone: "Asia/Shanghai",
    now: new Date("2026-07-03T15:30:00.000Z")
  });

  assert.equal(parsed.schemaVersion, expected.schemaVersion);
  assert.equal(parsed.status, "ok");
  assert.equal(parsed.fiveHour.remainingPercent, expected.fiveHour.remainingPercent);
  assert.equal(parsed.fiveHour.resetLabel, expected.fiveHour.resetLabel);
  assert.equal(parsed.fiveHour.resetAt, expected.fiveHour.resetAt);
  assert.equal(parsed.weekly.remainingPercent, expected.weekly.remainingPercent);
  assert.equal(parsed.weekly.resetLabel, expected.weekly.resetLabel);
  assert.equal(parsed.weekly.resetAt, expected.weekly.resetAt);
  assert.equal(parsed.source.sourceKind, expected.source.sourceKind);
});

test("parses rendered analytics text and ignores Spark limits", () => {
  const source = fs.readFileSync("extension/fixtures/usage-source-v2.analytics-dom.txt", "utf8");

  const parsed = parseUsageSource(source, {
    timeZone: "Asia/Shanghai",
    now: new Date("2026-07-03T16:10:00.000Z")
  });

  assert.equal(parsed.status, "ok");
  assert.equal(parsed.fiveHour.remainingPercent, 56);
  assert.equal(parsed.fiveHour.resetLabel, "01:22");
  assert.equal(parsed.weekly.remainingPercent, 5);
  assert.equal(parsed.weekly.resetLabel, "7/7");
  assert.equal(parsed.source.sourceKind, "chatgpt-analytics-dom");
});
