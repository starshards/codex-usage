export const HOST_NAME = "com.starshards.codex_usage";

export function createRequestTracker() {
  const pending = new Map();
  return {
    waitFor(requestId) {
      return new Promise((resolve, reject) => {
        pending.set(requestId, { resolve, reject });
      });
    },
    resolve(message) {
      const entry = pending.get(message.requestId);
      if (!entry) return;
      pending.delete(message.requestId);
      entry.resolve(message);
    },
    rejectAll(error) {
      for (const entry of pending.values()) entry.reject(error);
      pending.clear();
    }
  };
}

export function createNativeClient(chromeRuntime = chrome.runtime) {
  const tracker = createRequestTracker();
  const eventListeners = new Set();
  let port = null;

  function connect() {
    if (port) return port;

    port = chromeRuntime.connectNative(HOST_NAME);
    port.onMessage.addListener((message) => {
      if (message.requestId) {
        tracker.resolve(message);
        return;
      }

      for (const listener of eventListeners) listener(message);
    });
    port.onDisconnect.addListener(() => {
      const message = chromeRuntime.lastError?.message ?? "native host disconnected";
      tracker.rejectAll(new Error(message));
      port = null;
    });
    return port;
  }

  async function request(message) {
    if (!port) connect();
    const requestId = message.requestId ?? crypto.randomUUID();
    const response = tracker.waitFor(requestId);
    port.postMessage({ ...message, requestId });
    return response;
  }

  function onEvent(listener) {
    eventListeners.add(listener);
    return () => eventListeners.delete(listener);
  }

  return { connect, request, onEvent };
}
