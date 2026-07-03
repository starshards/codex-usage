import test from "node:test";
import assert from "node:assert/strict";
import { createRequestTracker } from "../src/nativeClient.js";

test("tracks pending native requests by request id", async () => {
  const tracker = createRequestTracker();
  const promise = tracker.waitFor("abc");
  tracker.resolve({ requestId: "abc", type: "status", codexRunning: true });

  await assert.doesNotReject(promise);
  assert.equal((await promise).codexRunning, true);
});
