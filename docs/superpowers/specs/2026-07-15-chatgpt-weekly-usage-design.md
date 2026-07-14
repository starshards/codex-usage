# ChatGPT Weekly Usage Compatibility Design

## Goal

Adapt the menu bar app to the July 2026 ChatGPT desktop update, where the Codex quota event contains one weekly window instead of separate five-hour and weekly windows.

The status item remains compact and refreshes every five seconds:

```text
ChatGPT
1w 100% 7月22日
```

## Observed Format Change

The current local session event uses:

- `rate_limits.primary.window_minutes = 10080`
- `rate_limits.secondary = null`

The existing decoder requires both windows, so it rejects the new event and falls back to stale cached data.

## Data Model And Parsing

Both `primary` and `secondary` become optional while decoding session events. The parser identifies windows by `window_minutes`, rather than assuming that `primary` always means five hours and `secondary` always means one week.

- A 300-minute window maps to the existing five-hour field.
- A 10080-minute window maps to the weekly field.
- The new weekly-only event produces no five-hour field and one weekly field.
- The previous two-window format remains supported permanently, including if ChatGPT restores the five-hour quota later.
- Spark-specific limits remain excluded.

## Display And Menu

When only the weekly window exists, the status item shows `ChatGPT` on the first line and the weekly remaining percentage plus reset date on the second line. The menu contains only the weekly quota row, status, refresh, usage-page, and quit actions.

The existing two-window presentation remains unchanged for any valid event containing both windows:

```text
5h 72% 18:30
1w 41% 7月22日
```

If ChatGPT restores the five-hour quota later, the app automatically returns to this original display. Error and paused states use `ChatGPT --` instead of `Codex --`.

The refresh interval remains five seconds.

## Process Detection

The installed ChatGPT desktop app still uses bundle identifier `com.openai.codex`, so bundle-based detection remains authoritative. Name-based fallbacks also recognize `ChatGPT` for compatibility with the renamed application.

## Error Handling

Malformed windows are ignored without inventing quota values. If no supported quota window can be decoded, the existing cache fallback remains in effect. A valid weekly-only event must replace an older cached two-window snapshot.

## Verification

Tests cover:

- Decoding the new weekly-only event with `secondary: null`.
- Mapping windows by `window_minutes` for both old and new formats.
- Preserving the original `5h + 1w` display when both windows are present.
- Preserving Spark filtering.
- Formatting the weekly-only two-line status item.
- Showing only the weekly menu row.
- Recognizing the ChatGPT localized application name.
- Keeping all existing tests green.
