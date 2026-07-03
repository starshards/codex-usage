import { okUsagePayload, statusPayload } from "./usageTypes.js";

export function parseUsageSource(sourceText, options = {}) {
  try {
    const source = JSON.parse(String(sourceText));
    const primary = source?.rate_limit?.primary_window;
    const secondary = source?.rate_limit?.secondary_window;

    return okUsagePayload({
      fiveHour: parseWindow(primary, "time", options),
      weekly: parseWindow(secondary, "weekday", options)
    }, options);
  } catch {
    return statusPayload("parse_failed", options);
  }
}

function parseWindow(window, labelKind, options) {
  const usedPercent = finiteNumber(window?.used_percent);
  const resetAtSeconds = finiteNumber(window?.reset_at);
  const resetDate = new Date(resetAtSeconds * 1000);

  return {
    remainingPercent: clampPercent(100 - usedPercent),
    resetLabel: labelKind === "weekday"
      ? formatWeekday(resetDate, options.timeZone)
      : formatTime(resetDate, options.timeZone),
    resetAt: resetDate.toISOString()
  };
}

function finiteNumber(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    throw new Error("expected finite number");
  }
  return number;
}

function clampPercent(value) {
  return Math.max(0, Math.min(100, Math.round(value)));
}

function formatTime(date, timeZone) {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  }).format(date);
}

function formatWeekday(date, timeZone) {
  return new Intl.DateTimeFormat("en-US", {
    timeZone,
    weekday: "short"
  }).format(date);
}
