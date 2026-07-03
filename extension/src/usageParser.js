import { okUsagePayload, statusPayload } from "./usageTypes.js";

export function parseUsageSource(sourceText, options = {}) {
  const source = String(sourceText);
  try {
    const value = JSON.parse(source);
    const primary = value?.rate_limit?.primary_window;
    const secondary = value?.rate_limit?.secondary_window;

    return okUsagePayload({
      fiveHour: parseWindow(primary, "time", options),
      weekly: parseWindow(secondary, "weekday", options)
    }, options);
  } catch {
    const analyticsText = tryParseAnalyticsText(source, options);
    if (analyticsText) {
      return okUsagePayload(analyticsText, {
        ...options,
        sourceKind: "chatgpt-analytics-dom"
      });
    }
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

function tryParseAnalyticsText(source, options) {
  const mainText = source.split(/GPT-5\.3-Codex-Spark/i)[0];
  const lines = mainText.split(/\n+/).map(line => line.trim()).filter(Boolean);
  const blocks = [];

  for (let index = 0; index < lines.length; index += 1) {
    const percentMatch = lines[index].match(/^([0-9]{1,3})%$/);
    if (!percentMatch) continue;
    if (!/剩余|remaining/i.test(lines[index + 1] ?? "")) continue;
    const resetLine = lines.slice(index + 2, index + 5).find(line => /重置时间|reset/i.test(line));
    if (!resetLine) continue;
    blocks.push({
      remainingPercent: clampPercent(Number(percentMatch[1])),
      resetText: resetLine.replace(/^.*?(?:重置时间|reset(?:s| time)?)[：:\s]*/i, "")
    });
  }

  if (blocks.length < 2) return null;

  return {
    fiveHour: {
      remainingPercent: blocks[0].remainingPercent,
      resetLabel: normalizeTimeLabel(blocks[0].resetText),
      resetAt: null
    },
    weekly: {
      remainingPercent: blocks[1].remainingPercent,
      resetLabel: formatWeekday(parseChineseDateTime(blocks[1].resetText), options.timeZone),
      resetAt: parseChineseDateTime(blocks[1].resetText).toISOString()
    }
  };
}

function normalizeTimeLabel(value) {
  const match = String(value).match(/([0-9]{1,2}):([0-9]{2})/);
  if (!match) return String(value).trim();
  return `${match[1].padStart(2, "0")}:${match[2]}`;
}

function parseChineseDateTime(value) {
  const match = String(value).match(/([0-9]{4})年([0-9]{1,2})月([0-9]{1,2})日\s+([0-9]{1,2}):([0-9]{2})/);
  if (!match) throw new Error("expected Chinese datetime");
  const [, year, month, day, hour, minute] = match.map(Number);
  return new Date(year, month - 1, day, hour, minute, 0);
}
