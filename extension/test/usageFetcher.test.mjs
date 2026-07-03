import test from "node:test";
import assert from "node:assert/strict";
import { fetchUsageSource } from "../src/usageFetcher.js";

test("falls back to an existing ChatGPT tab when background fetch is not logged in", async () => {
  const chromeApi = {
    tabs: {
      async query(query) {
        assert.equal(query.url, "https://chatgpt.com/*");
        return [{ id: 123, url: "https://chatgpt.com/codex/cloud/settings/analytics" }];
      }
    },
    scripting: {
      async executeScript(options) {
        assert.equal(options.target.tabId, 123);
        assert.equal(options.world, "MAIN");
        return [{ result: { status: 200, ok: true, text: "{\"ok\":true}" } }];
      }
    }
  };

  const fetched = await fetchUsageSource("https://chatgpt.com/backend-api/wham/usage", {
    chromeApi,
    fetchImpl: async () => ({ status: 403, ok: false, text: async () => "" })
  });

  assert.equal(fetched.status, "ok");
  assert.equal(fetched.text, "{\"ok\":true}");
  assert.equal(fetched.detail, "tab_fetch_ok");
});

test("returns not_logged_in when no ChatGPT tab can perform the fallback fetch", async () => {
  const chromeApi = {
    tabs: { async query() { return []; } },
    scripting: { async executeScript() { throw new Error("should not run"); } }
  };

  const fetched = await fetchUsageSource("https://chatgpt.com/backend-api/wham/usage", {
    chromeApi,
    fetchImpl: async () => ({ status: 401, ok: false, text: async () => "" })
  });

  assert.equal(fetched.status, "not_logged_in");
  assert.equal(fetched.detail, "no_chatgpt_tab");
});

test("reports when the ChatGPT tab fallback is still not logged in", async () => {
  const chromeApi = {
    tabs: { async query() { return [{ id: 123 }]; } },
    scripting: {
      async executeScript() {
        return [{ result: { status: 401, ok: false, text: "" } }];
      }
    }
  };

  const fetched = await fetchUsageSource("https://chatgpt.com/backend-api/wham/usage", {
    chromeApi,
    fetchImpl: async () => ({ status: 403, ok: false, text: async () => "" })
  });

  assert.equal(fetched.status, "not_logged_in");
  assert.equal(fetched.detail, "tab_fetch_401");
});
