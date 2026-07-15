# ChatGPT Weekly Usage Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make the menu bar app read ChatGPT's weekly-only quota events while permanently preserving the original five-hour plus weekly behavior.

**Architecture:** Keep local Codex session JSONL as the authoritative source. Decode both rate-limit slots as optional, classify each window by `window_minutes`, and let the existing optional `UsageSnapshot` fields drive adaptive status and menu output.

**Tech Stack:** Swift 6, AppKit, XCTest, Swift Package Manager, existing shell packaging scripts

## Global Constraints

- Refresh every five seconds.
- Weekly-only status uses `ChatGPT` on line one and `1w <remaining> <reset date>` on line two.
- Any valid 300-minute plus 10080-minute event keeps the original `5h + 1w` display.
- Continue excluding `codex_bengalfox` / `GPT-5.3-Codex-Spark` limits.
- Do not re-enable Chrome/native-host cache writes.
- Do not rename the app bundle or cache schema.

---

### Task 1: Parse Weekly-Only And Legacy Rate Limits

**Files:**
- Modify: `Tests/CodexUsageSharedTests/CodexSessionRateLimitStoreTests.swift`
- Modify: `Sources/CodexUsageShared/CodexSessionRateLimitStore.swift`

**Interfaces:**
- Consumes: session JSONL `event_msg/token_count/rate_limits` events.
- Produces: `CodexSessionRateLimitStore.loadLatestSnapshot() -> UsageSnapshot?`, with `fiveHour` and `weekly` populated according to `window_minutes`.

- [x] **Step 1: Add a failing weekly-only decoding test**

Add this test to `CodexSessionRateLimitStoreTests`:

```swift
func testLoadsWeeklyOnlyRateLimitFromPrimaryWindow() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let sessionDirectory = root.appendingPathComponent("2026/07/15", isDirectory: true)
    try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
    let sessionFile = sessionDirectory.appendingPathComponent("rollout.jsonl")
    try #"{"timestamp":"2026-07-15T00:00:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":36,"window_minutes":10080,"resets_at":1783391609},"secondary":null,"plan_type":"prolite"}}}"#
        .write(to: sessionFile, atomically: true, encoding: .utf8)

    let store = CodexSessionRateLimitStore(
        sessionsDirectory: root,
        timeZone: TimeZone(identifier: "Asia/Shanghai")!
    )

    let snapshot = try XCTUnwrap(store.loadLatestSnapshot())

    XCTAssertNil(snapshot.fiveHour)
    XCTAssertEqual(snapshot.weekly?.remainingPercent, 64)
    XCTAssertEqual(snapshot.weekly?.resetLabel, "7月7日")
}
```

- [x] **Step 2: Run the new test and verify RED**

Run:

```bash
swift test --filter CodexSessionRateLimitStoreTests/testLoadsWeeklyOnlyRateLimitFromPrimaryWindow
```

Expected: FAIL because `CodexRateLimits.secondary` is non-optional and the event cannot decode.

- [x] **Step 3: Add a failing slot-independent mapping test**

Add this complete test:

```swift
func testMapsRateLimitWindowsByDurationInsteadOfSlot() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let sessionDirectory = root.appendingPathComponent("2026/07/15", isDirectory: true)
    try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
    let sessionFile = sessionDirectory.appendingPathComponent("rollout.jsonl")
    try #"{"timestamp":"2026-07-15T00:00:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":36,"window_minutes":10080,"resets_at":1783391609},"secondary":{"used_percent":25,"window_minutes":300,"resets_at":1783099357},"plan_type":"prolite"}}}"#
        .write(to: sessionFile, atomically: true, encoding: .utf8)

    let store = CodexSessionRateLimitStore(
        sessionsDirectory: root,
        timeZone: TimeZone(identifier: "Asia/Shanghai")!
    )

    let snapshot = try XCTUnwrap(store.loadLatestSnapshot())

    XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 75)
    XCTAssertEqual(snapshot.weekly?.remainingPercent, 64)
}
```

This proves slot order is not treated as quota meaning.

- [x] **Step 4: Run both parser tests and verify RED**

Run:

```bash
swift test --filter CodexSessionRateLimitStoreTests
```

Expected: the new tests fail while the existing legacy and Spark-filter tests pass.

- [x] **Step 5: Implement optional windows and duration-based mapping**

Change `CodexRateLimits` to:

```swift
private struct CodexRateLimits: Decodable {
    var limitId: String?
    var limitName: String?
    var primary: CodexRateLimitWindow?
    var secondary: CodexRateLimitWindow?

    var isSparkLimit: Bool {
        limitId == "codex_bengalfox" || limitName == "GPT-5.3-Codex-Spark"
    }

    var windows: [CodexRateLimitWindow] {
        [primary, secondary].compactMap { $0 }
    }

    enum CodingKeys: String, CodingKey {
        case limitId = "limit_id"
        case limitName = "limit_name"
        case primary
        case secondary
    }
}
```

Replace positional mapping in `snapshot(from:)` with:

```swift
let fiveHour = rateLimits.windows.first { $0.windowMinutes == 300 }
let weekly = rateLimits.windows.first { $0.windowMinutes == 10_080 }
guard fiveHour != nil || weekly != nil else { return nil }

return UsageSnapshot(
    schemaVersion: 1,
    status: .ok,
    fiveHour: fiveHour.map { quotaWindow(from: $0, labelKind: .time) },
    weekly: weekly.map { quotaWindow(from: $0, labelKind: .date) },
    updatedAt: timestamp,
    source: UsageSource(sourceKind: "codex-session-rate-limits")
)
```

- [x] **Step 6: Run parser tests and verify GREEN**

Run:

```bash
swift test --filter CodexSessionRateLimitStoreTests
```

Expected: all parser tests pass, including the unchanged legacy and Spark cases.

- [x] **Step 7: Commit Task 1**

```bash
git add Tests/CodexUsageSharedTests/CodexSessionRateLimitStoreTests.swift Sources/CodexUsageShared/CodexSessionRateLimitStore.swift
git commit -m "fix: parse weekly-only ChatGPT limits"
```

---

### Task 2: Adapt Status Text And Process Naming

**Files:**
- Modify: `Tests/CodexUsageSharedTests/UsageFormatterTests.swift`
- Modify: `Tests/CodexUsageSharedTests/ProcessStatusProviderTests.swift`
- Modify: `Sources/CodexUsageShared/UsageFormatter.swift`
- Modify: `Sources/CodexUsageShared/ProcessStatusProvider.swift`
- Modify: `Sources/CodexUsageMenubar/TwoLineStatusView.swift`

**Interfaces:**
- Consumes: a valid `UsageSnapshot` with either one or two quota windows.
- Produces: exactly two menu-bar strings from `UsageFormatter.menuBarLines(for:)` and ChatGPT-aware process detection.

- [x] **Step 1: Add failing weekly-only formatter and ChatGPT process tests**

Add this formatter test:

```swift
func testFormatsWeeklyOnlySnapshotAsTwoLines() {
    let snapshot = UsageSnapshot(
        schemaVersion: 1,
        status: .ok,
        fiveHour: nil,
        weekly: QuotaWindow(remainingPercent: 64, resetLabel: "7月22日", resetAt: nil),
        updatedAt: Date(),
        source: UsageSource(sourceKind: "codex-session-rate-limits")
    )

    XCTAssertEqual(UsageFormatter.menuBarLines(for: snapshot), ["ChatGPT", "1w 64% 7月22日"])
}
```

Add this process test:

```swift
func testDetectsRenamedChatGPTApplicationByLocalizedName() {
    let provider = ProcessStatusProvider(applications: [
        RunningApplication(bundleIdentifier: nil, localizedName: "ChatGPT")
    ])

    XCTAssertTrue(provider.isCodexRunning())
}
```

Keep the existing formatter test that asserts the original `5h + 1w` output unchanged.

- [x] **Step 2: Run focused tests and verify RED**

Run:

```bash
swift test --filter UsageFormatterTests
swift test --filter ProcessStatusProviderTests
```

Expected: weekly-only formatting returns fallback text and ChatGPT name detection returns false.

- [x] **Step 3: Implement adaptive two-line formatting**

At the start of `menuBarLines(for:)`, retain the status guard, then handle windows as follows:

```swift
guard snapshot.status == .ok else {
    return fallbackLines(for: snapshot.status)
}

if let fiveHour = snapshot.fiveHour, let weekly = snapshot.weekly {
    let labelWidth = max("5h".count, "1w".count)
    let percentWidth = max("\(fiveHour.remainingPercent)%".count, "\(weekly.remainingPercent)%".count)
    return [
        menuBarLine(windowLabel: "5h", percent: fiveHour.remainingPercent, resetLabel: fiveHour.resetLabel, labelWidth: labelWidth, percentWidth: percentWidth),
        menuBarLine(windowLabel: "1w", percent: weekly.remainingPercent, resetLabel: weekly.resetLabel, labelWidth: labelWidth, percentWidth: percentWidth)
    ]
}

if let weekly = snapshot.weekly {
    return ["ChatGPT", "1w \(weekly.remainingPercent)% \(weekly.resetLabel)"]
}

return fallbackLines(for: .noData)
```

Change fallback strings from `Codex --` to `ChatGPT --`. Change the initial first-line text in `TwoLineStatusView` from `Codex --` to `ChatGPT --`.

- [x] **Step 4: Recognize the renamed localized application**

Extend the existing process predicate with:

```swift
app.localizedName == "ChatGPT" ||
app.localizedName == "ChatGPT.app"
```

Keep `com.openai.codex`, `Codex`, and `Codex.app` compatibility checks.

- [x] **Step 5: Run focused tests and verify GREEN**

Run:

```bash
swift test --filter UsageFormatterTests
swift test --filter ProcessStatusProviderTests
```

Expected: all formatter and process tests pass, including old-format assertions.

- [x] **Step 6: Commit Task 2**

```bash
git add Tests/CodexUsageSharedTests/UsageFormatterTests.swift Tests/CodexUsageSharedTests/ProcessStatusProviderTests.swift Sources/CodexUsageShared/UsageFormatter.swift Sources/CodexUsageShared/ProcessStatusProvider.swift Sources/CodexUsageMenubar/TwoLineStatusView.swift
git commit -m "feat: adapt status display for ChatGPT quotas"
```

---

### Task 3: Verify Weekly Menu, Build, And Relaunch

**Files:**
- Modify: `Tests/CodexUsageMenubarTests/TwoLineStatusViewTests.swift`
- Modify: `Sources/CodexUsageMenubar/StatusItemController.swift`
- Generated locally: `dist/Codex Usage.app`

**Interfaces:**
- Consumes: `UsageSnapshot` from Tasks 1 and 2.
- Produces: menu quota titles that omit the five-hour row when `fiveHour == nil`.

- [x] **Step 1: Add a failing weekly-only menu-title test**

Add an internal static helper contract and write the test first:

```swift
func testWeeklyOnlySnapshotProducesOnlyWeeklyMenuTitle() {
    let snapshot = UsageSnapshot(
        schemaVersion: 1,
        status: .ok,
        fiveHour: nil,
        weekly: QuotaWindow(remainingPercent: 64, resetLabel: "7月22日", resetAt: nil),
        updatedAt: Date(),
        source: UsageSource(sourceKind: "codex-session-rate-limits")
    )

    XCTAssertEqual(StatusItemController.quotaMenuTitles(for: snapshot), ["Weekly: 64% until 7月22日"])
}
```

- [x] **Step 2: Run the menu-bar tests and verify RED**

Run:

```bash
swift test --filter CodexUsageMenubarTests
```

Expected: compile failure because `quotaMenuTitles(for:)` does not exist.

- [x] **Step 3: Implement and use the menu-title helper**

Add to `StatusItemController`:

```swift
static func quotaMenuTitles(for snapshot: UsageSnapshot) -> [String] {
    var titles: [String] = []
    if let fiveHour = snapshot.fiveHour {
        titles.append("5h: \(fiveHour.remainingPercent)% until \(fiveHour.resetLabel)")
    }
    if let weekly = snapshot.weekly {
        titles.append("Weekly: \(weekly.remainingPercent)% until \(weekly.resetLabel)")
    }
    return titles
}
```

Replace the two direct quota-row branches in `makeMenu()` with:

```swift
for title in Self.quotaMenuTitles(for: lastSnapshot) {
    menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
}
```

- [x] **Step 4: Run all automated tests**

Run:

```bash
npm test
git diff --check
```

Expected: Swift and JavaScript suites pass with no whitespace errors.

- [x] **Step 5: Build and relaunch the local app**

Run:

```bash
scripts/build-app.sh
pkill -f "/Users/star/myapp/codex-usage/dist/Codex Usage.app/Contents/MacOS/Codex Usage"
open "dist/Codex Usage.app"
```

Expected: the menu bar app restarts from the rebuilt bundle and writes a weekly-only `usage.json` snapshot within five seconds.

- [x] **Step 6: Verify the live cache**

Run:

```bash
jq '{status,fiveHour,weekly,updatedAt,source}' "$HOME/Library/Application Support/CodexUsageMenubar/usage.json"
```

Expected: `status` is `ok`, `fiveHour` is `null`, `weekly` contains the current remaining percentage and reset date, and `source.sourceKind` is `codex-session-rate-limits`.

- [x] **Step 7: Commit Task 3**

```bash
git add Tests/CodexUsageMenubarTests/TwoLineStatusViewTests.swift Sources/CodexUsageMenubar/StatusItemController.swift
git commit -m "test: cover weekly-only quota menu"
```
