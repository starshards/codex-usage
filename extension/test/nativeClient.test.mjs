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

test("dispatches unsolicited native events to listeners", () => {
  const messageListeners = [];
  const fakeRuntime = {
    connectNative() {
      return {
        onMessage: { addListener(listener) { messageListeners.push(listener); } },
        onDisconnect: { addListener() {} },
        postMessage() {}
      };
    }
  };
  const client = createNativeClient(fakeRuntime);
  const events = [];
  client.onEvent((message) => events.push(message));

  client.connect();
  messageListeners[0]({ type: "refresh_now", reason: "manual" });

  assert.deepEqual(events, [{ type: "refresh_now", reason: "manual" }]);
});
