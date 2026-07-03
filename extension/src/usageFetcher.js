export async function fetchUsageSource(sourceUrl, options = {}) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const chromeApi = options.chromeApi ?? globalThis.chrome;
  const response = await fetchImpl(sourceUrl, {
    method: "GET",
    credentials: "include",
    cache: "no-store"
  });

  if (response.status === 401 || response.status === 403) {
    const tabFetched = await fetchUsageSourceFromExistingChatGPTTab(sourceUrl, chromeApi);
    if (tabFetched) return tabFetched;
    return { status: "not_logged_in", text: "", detail: "no_chatgpt_tab" };
  }

  if (!response.ok) {
    return { status: "network_failed", text: "", detail: `background_fetch_${response.status}` };
  }

  return { status: "ok", text: await response.text(), detail: "background_fetch_ok" };
}

async function fetchUsageSourceFromExistingChatGPTTab(sourceUrl, chromeApi) {
  if (!chromeApi?.tabs?.query || !chromeApi?.scripting?.executeScript) {
    return null;
  }

  const tabs = await chromeApi.tabs.query({ url: "https://chatgpt.com/*" });
  const tab = tabs.find(candidate => typeof candidate.id === "number");
  if (!tab) return null;

  const results = await chromeApi.scripting.executeScript({
    target: { tabId: tab.id },
    world: "MAIN",
    args: [sourceUrl],
    func: async (url) => {
      const response = await fetch(url, {
        method: "GET",
        credentials: "include",
        cache: "no-store"
      });
      return {
        status: response.status,
        ok: response.ok,
        text: response.ok ? await response.text() : ""
      };
    }
  });

  const result = results?.[0]?.result;
  if (!result) return null;
  if (result.status === 401 || result.status === 403) {
    return { status: "not_logged_in", text: "", detail: `tab_fetch_${result.status}` };
  }
  if (!result.ok) {
    return { status: "network_failed", text: "", detail: `tab_fetch_${result.status}` };
  }
  return { status: "ok", text: result.text, detail: "tab_fetch_ok" };
}
