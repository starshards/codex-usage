import test from "node:test";
import assert from "node:assert/strict";
import { createNativeClient, createRequestTracker } from "../src/nativeClient.js";

test("tracks pending native requests by request id", async () => {
  const tracker = createRequestTracker();
  const promise = tracker.waitFor("abc");
  tracker.resolve({ requestId: "abc", type: "status", codexRunning: true });

  await assert.doesNotReject(promise);
  assert.equal((await promise).codexRunning, true);
});

test("rejects pending requests with native messaging lastError message", async () => {
  const disconnectListeners = [];
  const fakeRuntime = {
    lastError: { message: "Access to the specified native messaging host is forbidden." },
    connectNative() {
      return {
        onMessage: { addListener() {} },
        onDisconnect: { addListener(listener) { disconnectListeners.push(listener); } },
        postMessage() {}
      };
    }
  };
  const client = createNativeClient(fakeRuntime);

  const promise = client.request({ type: "get_status", requestId: "native-error" });
  disconnectListeners[0]();

  await assert.rejects(promise, /forbidden/);
});
