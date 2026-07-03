# Codex Usage Menubar Design

Date: 2026-07-03
Status: Approved design for implementation planning

## Summary

Build a personal macOS menu bar app that shows ChatGPT subscription Codex usage limits: the 5-hour quota and the weekly quota. The menu bar view uses two compact text rows, similar to an existing two-line network-speed status item:

```text
5h 72% 18:30
W  41% Mon
```

The app is for personal use. Installation can rely on local development steps and Chrome developer-mode extension loading. The design does not target public distribution, signing, notarization, or Chrome Web Store publishing in v1.

## Goals

- Show 5-hour Codex quota percentage and reset/end time.
- Show weekly Codex quota percentage and reset/end day or time.
- Use a native macOS menu bar UI built with Swift/SwiftUI and AppKit.
- Refresh roughly once per minute while the Codex desktop app is running.
- Pause refreshes when the Codex desktop app is not running.
- Avoid refreshes during Mac sleep; refresh immediately after wake.
- Reuse Chrome's existing ChatGPT login state through a companion Chrome extension.
- Avoid storing cookies, tokens, raw HTML, raw API responses, or request headers locally.
- Cache only the last parsed usage result and status for display when offline or stale.

## Non-Goals

- Notification reminders.
- Low-quota color changes or warning colors.
- Historical trend charts.
- Multi-account support.
- Public installer, signing, notarization, or Chrome Web Store release.
- Reading Codex quota or billing from local Codex files.
- Saving or forwarding ChatGPT cookies, tokens, headers, or full response bodies.
- OpenAI API billing or API usage tracking.

## Architecture

The system has three pieces:

1. macOS menu bar app
   - Native Swift/SwiftUI app.
   - Uses AppKit `NSStatusItem` with a custom compact two-line view.
   - Owns the visible UI, local cache, process detection for the Codex desktop app, sleep/wake handling, and native app lifecycle.

2. Chrome extension
   - Manifest V3 extension loaded in Chrome developer mode.
   - Uses Chrome's existing ChatGPT login state.
   - Runs a once-per-minute background alarm.
   - Requests and parses the ChatGPT/Codex usage source in the background.
   - Sends only parsed usage fields to the native side.

3. Native Messaging host
   - Registered with Chrome for the companion extension.
   - Provides a narrow JSON protocol between the extension and local app logic.
   - Answers whether the Codex desktop app is running.
   - Accepts parsed usage updates and makes them available to the menu bar app.

The recommended implementation is:

```text
Chrome extension -> Native Messaging host -> local app/cache -> menu bar UI
```

No localhost server is required in v1.

## Data Model

The native side stores only this parsed shape:

```json
{
  "schemaVersion": 1,
  "status": "ok",
  "fiveHour": {
    "remainingPercent": 72,
    "resetLabel": "18:30",
    "resetAt": "2026-07-03T18:30:00+08:00"
  },
  "weekly": {
    "remainingPercent": 41,
    "resetLabel": "Mon",
    "resetAt": "2026-07-06T00:00:00+08:00"
  },
  "updatedAt": "2026-07-03T21:55:00+08:00",
  "source": {
    "parserVersion": "1",
    "sourceKind": "chatgpt-web-usage"
  }
}
```

When a reset timestamp is not available, the parser still provides a compact `resetLabel` if the official UI or response exposes one. The menu bar display uses labels first because they match the visible product wording and avoid over-formatting uncertain dates.

## Native Messaging Protocol

The protocol is newline-free Native Messaging JSON framed by Chrome.

Request from extension:

```json
{
  "type": "get_status",
  "requestId": "uuid"
}
```

Response from host:

```json
{
  "type": "status",
  "requestId": "uuid",
  "codexRunning": true,
  "lastUsage": {
    "status": "ok"
  }
}
```

Usage update from extension:

```json
{
  "type": "usage_update",
  "requestId": "uuid",
  "payload": {
    "schemaVersion": 1,
    "status": "ok",
    "fiveHour": {
      "remainingPercent": 72,
      "resetLabel": "18:30"
    },
    "weekly": {
      "remainingPercent": 41,
      "resetLabel": "Mon"
    },
    "updatedAt": "2026-07-03T21:55:00+08:00",
    "source": {
      "parserVersion": "1",
      "sourceKind": "chatgpt-web-usage"
    }
  }
}
```

Error update from extension:

```json
{
  "type": "usage_update",
  "requestId": "uuid",
  "payload": {
    "schemaVersion": 1,
    "status": "parse_failed",
    "updatedAt": "2026-07-03T21:55:00+08:00",
    "source": {
      "parserVersion": "1",
      "sourceKind": "chatgpt-web-usage"
    }
  }
}
```

Recognized statuses:

- `ok`
- `paused_codex_not_running`
- `not_logged_in`
- `network_failed`
- `parse_failed`
- `no_data`

## Refresh Behavior

Normal refresh:

1. Chrome extension alarm fires every minute.
2. Extension asks the Native Messaging host for status.
3. If Codex desktop app is not running, extension skips network fetch and reports `paused_codex_not_running`.
4. If Codex desktop app is running, extension fetches the ChatGPT/Codex usage source using Chrome login state.
5. Extension parses 5-hour and weekly usage fields.
6. Extension sends parsed usage JSON to the native side.
7. Menu bar app updates display and writes the parsed result to local cache.

Sleep and wake:

- No refresh is expected during sleep.
- The native app listens for wake notifications.
- After wake, the native side triggers or requests one immediate refresh.
- The normal one-minute extension alarm then continues.

Manual refresh:

- The popover/menu includes `Refresh Now`.
- Manual refresh follows the same Codex-running check and parsing path.

## UI

Menu bar status item:

```text
5h 72% 18:30
W  41% Mon
```

Rules:

- Use compact two-line text.
- Use a smaller font and tight line spacing.
- Use a single system text color in v1.
- Do not use warning colors in v1.
- Keep the view width stable enough that updates do not cause distracting layout jumps.
- Prefer compact reset labels in the menu bar. Full reset timestamps are shown in the detail menu.

Detail popover or menu:

- 5-hour quota: remaining percentage and full reset/end time.
- Weekly quota: remaining percentage and full reset/end time.
- Last successful update time.
- Current status: normal, Codex not running, not logged in, parse failed, network failed, or stale.
- Actions:
  - Refresh Now
  - Open ChatGPT Usage Page
  - Open Chrome Extension
  - Quit

Fallback menu bar states:

- Codex not running: `Paused`
- Not logged in: `Login`
- Parse or network failure with cached data: keep showing cached values and mark detail view as stale.
- No cached data: `Codex --`

## Codex Process Detection

The native side determines whether the macOS Codex desktop app is running by checking the local process list or workspace application state. The first implementation can match the app bundle/process name used by the installed Codex desktop app.

The process check is used only to decide whether refreshes should run. It does not inspect Codex auth files, local sqlite databases, logs, or thread content.

## Privacy and Security

- The Chrome extension depends on Chrome's existing authenticated ChatGPT session.
- The extension does not send cookies, tokens, request headers, raw HTML, or raw API response bodies to the native app.
- The native app stores only parsed usage data, timestamps, parser metadata, and status.
- Logs do not include raw responses by default.
- A debug mode may store explicitly redacted parser diagnostics, but it is disabled by default.
- Chrome host permissions are limited to ChatGPT/OpenAI usage sources required for this tool.
- The Native Messaging host manifest allows only the companion extension ID.

## Installation Model

Because this is personal-use software, v1 installation can be manual:

1. Build or run the Swift menu bar app locally.
2. Install/register the Native Messaging host manifest for Chrome.
3. Load the Chrome extension in developer mode.
4. Confirm the extension can connect to the host.
5. Confirm Chrome is logged into ChatGPT.
6. Start Codex desktop app and verify the menu bar item updates.

The repository should include scripts for host registration and development checks, but does not need a public installer in v1.

## Testing Strategy

Swift/native tests:

- Format two-line menu bar text from complete payloads.
- Preserve cached data when status is stale.
- Render fallback states for paused, login required, network failure, parse failure, and no data.
- Save and load local cache.
- Detect Codex process running/not running through an injectable process provider.
- Handle wake event by requesting an immediate refresh.

Chrome extension tests:

- Parse fixture payloads for 5-hour and weekly usage.
- Return `not_logged_in` when the source indicates authentication is missing.
- Return `parse_failed` when expected usage fields are absent.
- Avoid sending raw source text to native messages.
- Skip network fetch when Native Messaging reports Codex is not running.

Native Messaging tests:

- Validate request and response JSON shapes.
- Reject unknown message types safely.
- Persist `usage_update` payloads.
- Return cached status to the extension.

Manual acceptance:

- With Codex running and Chrome logged in, menu bar updates within one minute.
- With Codex quit, refresh pauses and no network fetch is attempted.
- After Mac wake, a refresh is attempted immediately.
- If parsing fails, cached values remain visible and detail view marks them stale.
- No token, cookie, header, raw HTML, or full raw response is saved in native cache or logs.

## Known Risks

- ChatGPT/Codex usage source may not be a stable public API. Parser changes may be required when the official web UI or internal response shape changes.
- Chrome MV3 service workers can be suspended, so alarm and Native Messaging behavior should be tested in real Chrome, not only unit tests.
- Native Messaging setup is sensitive to extension ID and manifest path, so development docs and scripts should make verification explicit.
- macOS menu bar two-line custom views are less standard than a single-line title. The implementation should keep the view simple, compact, and visually close to the user's existing two-line status item.

## Implementation Readiness

The design is intentionally scoped for a single implementation plan:

- One native app target.
- One Chrome extension.
- One Native Messaging host bridge.
- One parser module with fixtures.
- One local cache format.

No implementation should begin until the written spec is reviewed and accepted.
