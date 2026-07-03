# Manual Verification

Date: 2026-07-03

## Setup

1. Run `scripts/build-app.sh`.
2. Load `extension/` as an unpacked extension in `chrome://extensions`.
3. Copy the extension ID.
4. Run `scripts/register-native-host.sh <extension-id>`.
5. Start `dist/Codex Usage.app`.
6. Ensure Chrome is logged into ChatGPT.
7. Ensure Codex desktop app is running.

## Checks

- Menu bar shows two compact rows.
- With Codex running, values update within one minute.
- With Codex quit, extension sends `paused_codex_not_running` and skips usage fetch.
- With Chrome logged out, menu shows login state.
- With parser failure, previous cached values remain visible and menu marks status.
- After Mac wake or unlock, Chrome reports an `idle` state change to `active` and the extension attempts a refresh.
- Native cache file does not contain cookies, tokens, headers, raw HTML, or raw full JSON responses.

## Results

- Automated Swift tests: PASS, `swift test`, 10 tests.
- Extension tests: PASS, `npm run test:extension`, 4 tests.
- Swift build: PASS, `swift build`.
- Native host smoke test: PASS, `node scripts/smoke-native-host.mjs`, returned `type: status` and `codexRunning: true`.
- App bundle build: PASS, `scripts/build-app.sh`, created `dist/Codex Usage.app`.
- Manual Chrome extension check: PENDING, requires loading `extension/` in Chrome and running `scripts/register-native-host.sh <extension-id>` with the generated extension ID.
