import { createNativeClient } from "./nativeClient.js";
import { fetchUsageSource } from "./usageFetcher.js";
import { parseUsageSource } from "./usageParser.js";
import { USAGE_SOURCE_URL } from "./usageSourceConfig.js";
import { statusPayload } from "./usageTypes.js";

const nativeClient = createNativeClient();
const REFRESH_ALARM = "codex-usage-refresh";

chrome.runtime.onInstalled.addListener(async () => {
  chrome.idle.setDetectionInterval(60);
  await ensureRefreshAlarm();
  nativeClient.connect();
  refreshUsage("installed");
});

chrome.runtime.onStartup.addListener(async () => {
  chrome.idle.setDetectionInterval(60);
  await ensureRefreshAlarm();
  nativeClient.connect();
  refreshUsage("startup");
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === REFRESH_ALARM) refreshUsage("alarm");
});

chrome.idle.onStateChanged.addListener((state) => {
  if (state === "active") refreshUsage("idle_active");
});

async function ensureRefreshAlarm() {
  await chrome.alarms.create(REFRESH_ALARM, { periodInMinutes: 1 });
}

async function refreshUsage(reason) {
  try {
    const status = await nativeClient.request({ type: "get_status" });
    if (!status.codexRunning) {
      await nativeClient.request({
        type: "usage_update",
        payload: statusPayload("paused_codex_not_running")
      });
      return;
    }

    const fetched = await fetchUsageSource(USAGE_SOURCE_URL);
    const payload = fetched.status === "ok"
      ? parseUsageSource(fetched.text)
      : statusPayload(fetched.status, {
        sourceKind: `chatgpt-wham-usage:${fetched.detail ?? "unknown"}`
      });
    payload.reason = reason;
    await nativeClient.request({ type: "usage_update", payload });
  } catch {
    await nativeClient.request({
      type: "usage_update",
      payload: statusPayload("network_failed")
    });
  }
}
