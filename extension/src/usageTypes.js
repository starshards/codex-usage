import { USAGE_SOURCE_KIND } from "./usageSourceConfig.js";

export function okUsagePayload({ fiveHour, weekly }, options = {}) {
  return {
    schemaVersion: 1,
    status: "ok",
    fiveHour,
    weekly,
    updatedAt: (options.now ?? new Date()).toISOString(),
    source: {
      parserVersion: "1",
      sourceKind: options.sourceKind ?? USAGE_SOURCE_KIND
    }
  };
}

export function statusPayload(status, options = {}) {
  return {
    schemaVersion: 1,
    status,
    updatedAt: (options.now ?? new Date()).toISOString(),
    source: {
      parserVersion: "1",
      sourceKind: options.sourceKind ?? USAGE_SOURCE_KIND
    }
  };
}
