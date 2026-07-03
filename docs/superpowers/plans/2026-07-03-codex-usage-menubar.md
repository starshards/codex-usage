# Codex Usage Menubar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal macOS menu bar app that shows ChatGPT Codex 5-hour and weekly usage percentages plus reset labels.

**Architecture:** Use a Swift Package with a native menu bar executable, a native messaging host executable, a native host core library, and a shared Swift library for models/cache/protocol. Use a Manifest V3 Chrome extension to fetch authenticated ChatGPT/Codex usage data through Chrome's login state, parse it, and send only parsed fields to the native host. Start with a source-discovery gate so implementation is grounded in the actual authenticated usage response instead of an invented endpoint.

**Tech Stack:** Swift Package Manager, AppKit, SwiftUI, Foundation, XCTest, JavaScript ES modules, Node built-in test runner, Chrome Manifest V3, Chrome Native Messaging.

---

## Reference Notes

- Chrome Native Messaging uses a registered host manifest, `stdin`/`stdout`, and 32-bit length-prefixed JSON messages. On macOS, the user-level host manifest belongs under `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`.
- Chrome extensions need the `nativeMessaging` permission for `runtime.connectNative()` or `runtime.sendNativeMessage()`.
- Manifest V3 service workers can be suspended; use `chrome.alarms` for periodic refresh and make the worker resilient to restarts.
- Chrome 120 supports alarms at periods shorter than one minute, but this app intentionally uses one minute.
- Chrome `idle` events can request a refresh when the system becomes active after idle/lock, which is the extension-side wake recovery path.
- Cross-origin fetches from the extension service worker require explicit `host_permissions`; keep these limited to `https://chatgpt.com/*` and `https://*.openai.com/*` unless discovery proves a narrower list.

## Source Discovery Gate

The exact authenticated ChatGPT/Codex usage source is not yet known. Do not implement quota parsing against guessed endpoints. The first execution task creates a tiny extension-side discovery harness that records only a redacted response shape and a manually reviewed fixture. After that fixture exists, the parser and app work can proceed.

The discovery artifact is:

- `docs/usage-source-contract.md`: human-readable source URL, method, response kind, and redaction rules.
- `extension/fixtures/usage-source-v1.redacted.json`: redacted fixture if the source is JSON.
- `extension/fixtures/usage-source-v1.redacted.txt`: redacted fixture if the source is HTML/text.

If discovery cannot find a source that exposes both 5-hour and weekly usage, stop implementation and return to design. Do not scrape local Codex auth files as a fallback.

## File Structure

Create these files:

- `Package.swift`: Swift package with shared library, menu bar executable, native host executable, and XCTest target.
- `Sources/CodexUsageShared/UsageModels.swift`: quota/status/cache model types.
- `Sources/CodexUsageShared/UsageFormatter.swift`: two-line menu bar formatting and fallback labels.
- `Sources/CodexUsageShared/UsageCacheStore.swift`: atomic JSON cache read/write in Application Support.
- `Sources/CodexUsageShared/NativeMessages.swift`: Native Messaging message and response types.
- `Sources/CodexUsageShared/NativeMessageCodec.swift`: length-prefixed JSON encode/decode.
- `Sources/CodexUsageShared/ProcessStatusProvider.swift`: injectable Codex process detection.
- `Sources/CodexUsageNativeHost/main.swift`: native messaging host entry point.
- `Sources/CodexUsageNativeHostCore/NativeHostController.swift`: request handling and cache writes.
- `Sources/CodexUsageMenubar/main.swift`: AppKit app entry point.
- `Sources/CodexUsageMenubar/AppDelegate.swift`: app lifecycle.
- `Sources/CodexUsageMenubar/StatusItemController.swift`: `NSStatusItem` setup and menu/popover actions.
- `Sources/CodexUsageMenubar/TwoLineStatusView.swift`: compact two-line status item view.
- `Sources/CodexUsageMenubar/WakeObserver.swift`: wake notification handling.
- `Tests/CodexUsageSharedTests/*`: Swift unit tests for shared model, formatter, cache, codec, and process provider.
- `Tests/CodexUsageNativeHostCoreTests/*`: Swift unit tests for native host request handling.
- `extension/manifest.json`: Chrome MV3 manifest.
- `extension/src/background.js`: service worker wiring for alarms, native port, refresh flow.
- `extension/src/nativeClient.js`: request/response wrapper around `chrome.runtime.connectNative`.
- `extension/src/usageFetcher.js`: fetch usage source with credentials.
- `extension/src/usageParser.js`: parser for the redacted source fixture.
- `extension/src/usageTypes.js`: validation helpers for parsed payloads.
- `extension/test/*.test.mjs`: Node tests for parser, payload validation, and source redaction.
- `extension/fixtures/*`: redacted source and expected parsed output.
- `native-host/com.starshards.codex_usage.json.template`: Chrome Native Messaging manifest template.
- `scripts/build-app.sh`: build Swift executables and assemble a local `.app`.
- `scripts/register-native-host.sh`: write Chrome native host manifest for the current checkout.
- `scripts/smoke-native-host.mjs`: send one length-prefixed test message to the host binary.
- `docs/usage-source-contract.md`: source discovery result.

## Task 1: Discover and Freeze the Usage Source Contract

**Files:**
- Create: `docs/usage-source-contract.md`
- Create: `extension/fixtures/usage-source-v1.redacted.json`
- Create: `extension/fixtures/usage-source-v1.redacted.txt`
- Create: `extension/fixtures/usage-expected-v1.json`
- Create: `extension/src/redactSource.js`
- Create: `extension/src/usageSourceConfig.js`
- Test: `extension/test/redactSource.test.mjs`

- [ ] **Step 1: Create the redaction test**

```js
// extension/test/redactSource.test.mjs
import test from "node:test";
import assert from "node:assert/strict";
import { redactSourceText } from "../src/redactSource.js";

test("redacts obvious secrets while preserving usage words", () => {
  const input = [
    "authorization: Bearer secret-token",
    "cookie: session=abc123",
    "5h usage remaining 72% resets at 18:30",
    "weekly usage remaining 41% resets Monday"
  ].join("\n");

  const redacted = redactSourceText(input);

  assert.equal(redacted.includes("secret-token"), false);
  assert.equal(redacted.includes("abc123"), false);
  assert.equal(redacted.includes("5h usage remaining 72%"), true);
  assert.equal(redacted.includes("weekly usage remaining 41%"), true);
});
```

- [ ] **Step 2: Run the redaction test and verify it fails**

Run: `node --test extension/test/redactSource.test.mjs`

Expected: FAIL because `extension/src/redactSource.js` does not exist.

- [ ] **Step 3: Implement the redactor**

```js
// extension/src/redactSource.js
export function redactSourceText(text) {
  return String(text)
    .replace(/(authorization\s*:\s*bearer\s+)[^\s\\]+/gi, "$1[REDACTED]")
    .replace(/(cookie\s*:\s*)[^\n\r]+/gi, "$1[REDACTED]")
    .replace(/("accessToken"\s*:\s*")[^"]+(")/gi, "$1[REDACTED]$2")
    .replace(/("id_token"\s*:\s*")[^"]+(")/gi, "$1[REDACTED]$2")
    .replace(/("session"\s*:\s*")[^"]+(")/gi, "$1[REDACTED]$2");
}
```

- [ ] **Step 4: Run the redaction test and verify it passes**

Run: `node --test extension/test/redactSource.test.mjs`

Expected: PASS.

- [ ] **Step 5: Manually discover the authenticated source**

In Chrome with ChatGPT logged in:

1. Open the official ChatGPT/Codex usage UI that shows the 5-hour and weekly limits.
2. Open DevTools Network.
3. Refresh the usage UI.
4. Find the request whose response contains both the 5-hour quota and the weekly quota.
5. Copy only the response body, not request headers or cookies.
6. Redact it with `redactSourceText`.
7. Save the redacted body to exactly one fixture:
   - JSON source: `extension/fixtures/usage-source-v1.redacted.json`
   - Text/HTML source: `extension/fixtures/usage-source-v1.redacted.txt`
8. Save the authenticated source URL in `extension/src/usageSourceConfig.js`:

```js
// extension/src/usageSourceConfig.js
export const USAGE_SOURCE_URL = "https://chatgpt.com/codex/";
```

The string must be the exact request URL found in the Network panel. The `https://chatgpt.com/codex/` value is correct only when that page response itself contains both quota windows.

9. Save the expected parsed output to `extension/fixtures/usage-expected-v1.json`:

```json
{
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
  "source": {
    "parserVersion": "1",
    "sourceKind": "chatgpt-web-usage"
  }
}
```

- [ ] **Step 6: Write the source contract**

Create `docs/usage-source-contract.md`:

```markdown
# Usage Source Contract

Date: 2026-07-03

## Source

- Browser: Google Chrome
- Authentication: existing Chrome ChatGPT session
- Method: GET
- URL: the literal value committed in `extension/src/usageSourceConfig.js`
- Response kind: JSON or text, matching the redacted fixture in `extension/fixtures/`

## Required Fields

- 5-hour Codex usage remaining percentage
- 5-hour reset or end label
- Weekly Codex usage remaining percentage
- Weekly reset or end label

## Redaction Rules

- Do not store request headers.
- Do not store cookies.
- Do not store tokens.
- Do not store raw non-redacted HTML or JSON.
- Fixtures may keep quota labels, percentages, reset labels, and object keys needed by the parser.

## Failure Rule

If no authenticated source exposes both quota windows, implementation stops and the product design must be revisited.
```

- [ ] **Step 7: Commit**

```bash
git add docs/usage-source-contract.md extension/src/redactSource.js extension/src/usageSourceConfig.js extension/test/redactSource.test.mjs extension/fixtures
git commit -m "docs: record Codex usage source contract"
```

## Task 2: Scaffold the Swift Package and JavaScript Test Runner

**Files:**
- Create: `Package.swift`
- Create: `package.json`
- Create: `.gitignore`

- [ ] **Step 1: Create package files**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexUsage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexUsageShared", targets: ["CodexUsageShared"]),
        .library(name: "CodexUsageNativeHostCore", targets: ["CodexUsageNativeHostCore"]),
        .executable(name: "CodexUsageMenubar", targets: ["CodexUsageMenubar"]),
        .executable(name: "CodexUsageNativeHost", targets: ["CodexUsageNativeHost"])
    ],
    targets: [
        .target(name: "CodexUsageShared"),
        .target(name: "CodexUsageNativeHostCore", dependencies: ["CodexUsageShared"]),
        .executableTarget(name: "CodexUsageMenubar", dependencies: ["CodexUsageShared"]),
        .executableTarget(name: "CodexUsageNativeHost", dependencies: ["CodexUsageNativeHostCore"]),
        .testTarget(name: "CodexUsageSharedTests", dependencies: ["CodexUsageShared"]),
        .testTarget(name: "CodexUsageNativeHostCoreTests", dependencies: ["CodexUsageNativeHostCore", "CodexUsageShared"])
    ]
)
```

```json
{
  "name": "codex-usage",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "swift test && npm run test:extension",
    "test:extension": "node --test extension/test/*.test.mjs"
  }
}
```

```gitignore
.build/
DerivedData/
dist/
*.xcuserstate
.DS_Store
node_modules/
extension/fixtures/*.raw.*
```

- [ ] **Step 2: Run tests and verify expected partial failure**

Run: `swift test`

Expected: PASS with no tests or compile with empty targets after source directories exist. If SwiftPM reports missing target directories, create empty directories with `.gitkeep` files and rerun.

Run: `npm run test:extension`

Expected: PASS if Task 1 tests exist and pass.

- [ ] **Step 3: Commit**

```bash
git add Package.swift package.json .gitignore
git commit -m "chore: scaffold Swift package and test runner"
```

## Task 3: Add Shared Usage Models and Formatting

**Files:**
- Create: `Sources/CodexUsageShared/UsageModels.swift`
- Create: `Sources/CodexUsageShared/UsageFormatter.swift`
- Test: `Tests/CodexUsageSharedTests/UsageFormatterTests.swift`

- [ ] **Step 1: Write failing formatter tests**

```swift
import XCTest
@testable import CodexUsageShared

final class UsageFormatterTests: XCTestCase {
    func testFormatsCompleteUsageForMenuBar() {
        let snapshot = UsageSnapshot.ok(
            fiveHour: QuotaWindow(remainingPercent: 72, resetLabel: "18:30", resetAt: nil),
            weekly: QuotaWindow(remainingPercent: 41, resetLabel: "Mon", resetAt: nil),
            updatedAt: Date(timeIntervalSince1970: 1_783_084_500)
        )

        XCTAssertEqual(UsageFormatter.menuBarLines(for: snapshot), ["5h 72% 18:30", "W  41% Mon"])
    }

    func testFormatsFallbackStates() {
        XCTAssertEqual(UsageFormatter.menuBarLines(for: .status(.pausedCodexNotRunning)), ["Paused", ""])
        XCTAssertEqual(UsageFormatter.menuBarLines(for: .status(.notLoggedIn)), ["Login", ""])
        XCTAssertEqual(UsageFormatter.menuBarLines(for: .status(.noData)), ["Codex --", ""])
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `swift test --filter UsageFormatterTests`

Expected: FAIL because shared types do not exist.

- [ ] **Step 3: Implement models and formatter**

```swift
// Sources/CodexUsageShared/UsageModels.swift
import Foundation

public enum UsageStatus: String, Codable, Equatable, Sendable {
    case ok
    case pausedCodexNotRunning = "paused_codex_not_running"
    case notLoggedIn = "not_logged_in"
    case networkFailed = "network_failed"
    case parseFailed = "parse_failed"
    case noData = "no_data"
}

public struct QuotaWindow: Codable, Equatable, Sendable {
    public var remainingPercent: Int
    public var resetLabel: String
    public var resetAt: Date?

    public init(remainingPercent: Int, resetLabel: String, resetAt: Date?) {
        self.remainingPercent = remainingPercent
        self.resetLabel = resetLabel
        self.resetAt = resetAt
    }
}

public struct UsageSource: Codable, Equatable, Sendable {
    public var parserVersion: String
    public var sourceKind: String

    public init(parserVersion: String = "1", sourceKind: String = "chatgpt-web-usage") {
        self.parserVersion = parserVersion
        self.sourceKind = sourceKind
    }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var status: UsageStatus
    public var fiveHour: QuotaWindow?
    public var weekly: QuotaWindow?
    public var updatedAt: Date
    public var source: UsageSource

    public static func ok(fiveHour: QuotaWindow, weekly: QuotaWindow, updatedAt: Date) -> UsageSnapshot {
        UsageSnapshot(schemaVersion: 1, status: .ok, fiveHour: fiveHour, weekly: weekly, updatedAt: updatedAt, source: UsageSource())
    }

    public static func status(_ status: UsageStatus, updatedAt: Date = Date(timeIntervalSince1970: 0)) -> UsageSnapshot {
        UsageSnapshot(schemaVersion: 1, status: status, fiveHour: nil, weekly: nil, updatedAt: updatedAt, source: UsageSource())
    }
}
```

```swift
// Sources/CodexUsageShared/UsageFormatter.swift
import Foundation

public enum UsageFormatter {
    public static func menuBarLines(for snapshot: UsageSnapshot) -> [String] {
        guard snapshot.status == .ok,
              let fiveHour = snapshot.fiveHour,
              let weekly = snapshot.weekly
        else {
            return fallbackLines(for: snapshot.status)
        }

        return [
            "5h \(fiveHour.remainingPercent)% \(fiveHour.resetLabel)",
            "W  \(weekly.remainingPercent)% \(weekly.resetLabel)"
        ]
    }

    private static func fallbackLines(for status: UsageStatus) -> [String] {
        switch status {
        case .pausedCodexNotRunning:
            return ["Paused", ""]
        case .notLoggedIn:
            return ["Login", ""]
        case .networkFailed, .parseFailed, .noData:
            return ["Codex --", ""]
        case .ok:
            return ["Codex --", ""]
        }
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift test --filter UsageFormatterTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexUsageShared Tests/CodexUsageSharedTests
git commit -m "feat: add usage models and formatter"
```

## Task 4: Add Atomic Cache Storage

**Files:**
- Create: `Sources/CodexUsageShared/UsageCacheStore.swift`
- Test: `Tests/CodexUsageSharedTests/UsageCacheStoreTests.swift`

- [ ] **Step 1: Write failing cache tests**

```swift
import XCTest
@testable import CodexUsageShared

final class UsageCacheStoreTests: XCTestCase {
    func testSavesAndLoadsSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = UsageCacheStore(directory: directory)
        let snapshot = UsageSnapshot.ok(
            fiveHour: QuotaWindow(remainingPercent: 72, resetLabel: "18:30", resetAt: nil),
            weekly: QuotaWindow(remainingPercent: 41, resetLabel: "Mon", resetAt: nil),
            updatedAt: Date(timeIntervalSince1970: 1_783_084_500)
        )

        try store.save(snapshot)

        XCTAssertEqual(try store.load(), snapshot)
    }

    func testMissingCacheReturnsNoData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = UsageCacheStore(directory: directory)

        XCTAssertEqual(try store.load().status, .noData)
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `swift test --filter UsageCacheStoreTests`

Expected: FAIL because `UsageCacheStore` does not exist.

- [ ] **Step 3: Implement cache store**

```swift
// Sources/CodexUsageShared/UsageCacheStore.swift
import Foundation

public struct UsageCacheStore: Sendable {
    public let directory: URL
    public let fileName: String

    public init(directory: URL = UsageCacheStore.defaultDirectory(), fileName: String = "usage.json") {
        self.directory = directory
        self.fileName = fileName
    }

    public static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexUsageMenubar", isDirectory: true)
    }

    public func load() throws -> UsageSnapshot {
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .status(.noData)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UsageSnapshot.self, from: data)
    }

    public func save(_ snapshot: UsageSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        let temp = directory.appendingPathComponent("\(fileName).tmp")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: temp, options: [.atomic])
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: temp, to: url)
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift test --filter UsageCacheStoreTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexUsageShared/UsageCacheStore.swift Tests/CodexUsageSharedTests/UsageCacheStoreTests.swift
git commit -m "feat: add usage cache store"
```

## Task 5: Add Native Messaging Protocol and Codec

**Files:**
- Create: `Sources/CodexUsageShared/NativeMessages.swift`
- Create: `Sources/CodexUsageShared/NativeMessageCodec.swift`
- Test: `Tests/CodexUsageSharedTests/NativeMessageCodecTests.swift`

- [ ] **Step 1: Write failing codec tests**

```swift
import XCTest
@testable import CodexUsageShared

final class NativeMessageCodecTests: XCTestCase {
    func testEncodesAndDecodesLengthPrefixedMessage() throws {
        let message = NativeRequest(type: .getStatus, requestId: "abc", payload: nil)
        let data = try NativeMessageCodec.encode(message)
        let decoded = try NativeMessageCodec.decode(NativeRequest.self, from: data)

        XCTAssertEqual(decoded.type, .getStatus)
        XCTAssertEqual(decoded.requestId, "abc")
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `swift test --filter NativeMessageCodecTests`

Expected: FAIL because native protocol types do not exist.

- [ ] **Step 3: Implement protocol types and codec**

```swift
// Sources/CodexUsageShared/NativeMessages.swift
import Foundation

public enum NativeRequestType: String, Codable, Sendable {
    case getStatus = "get_status"
    case usageUpdate = "usage_update"
}

public struct NativeRequest: Codable, Equatable, Sendable {
    public var type: NativeRequestType
    public var requestId: String
    public var payload: UsageSnapshot?

    public init(type: NativeRequestType, requestId: String, payload: UsageSnapshot?) {
        self.type = type
        self.requestId = requestId
        self.payload = payload
    }
}

public enum NativeEventType: String, Codable, Sendable {
    case status
    case ack
    case refreshNow = "refresh_now"
    case error
}

public struct NativeEvent: Codable, Equatable, Sendable {
    public var type: NativeEventType
    public var requestId: String?
    public var codexRunning: Bool?
    public var lastUsage: UsageSnapshot?
    public var reason: String?
    public var message: String?
}
```

```swift
// Sources/CodexUsageShared/NativeMessageCodec.swift
import Foundation

public enum NativeMessageCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let payload = try JSONEncoder().encode(value)
        var length = UInt32(payload.count).littleEndian
        var data = Data(bytes: &length, count: 4)
        data.append(payload)
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard data.count >= 4 else { throw CodecError.truncatedLength }
        let length = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        let payload = data.dropFirst(4)
        guard payload.count == Int(length) else { throw CodecError.lengthMismatch }
        return try JSONDecoder().decode(T.self, from: payload)
    }

    public enum CodecError: Error, Equatable {
        case truncatedLength
        case lengthMismatch
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift test --filter NativeMessageCodecTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexUsageShared/NativeMessages.swift Sources/CodexUsageShared/NativeMessageCodec.swift Tests/CodexUsageSharedTests/NativeMessageCodecTests.swift
git commit -m "feat: add native messaging protocol"
```

## Task 6: Add Codex Process Detection

**Files:**
- Create: `Sources/CodexUsageShared/ProcessStatusProvider.swift`
- Test: `Tests/CodexUsageSharedTests/ProcessStatusProviderTests.swift`

- [ ] **Step 1: Write failing process provider tests**

```swift
import XCTest
@testable import CodexUsageShared

final class ProcessStatusProviderTests: XCTestCase {
    func testDetectsCodexByBundleIdentifierOrName() {
        let provider = ProcessStatusProvider(applications: [
            RunningApplication(bundleIdentifier: "com.openai.codex", localizedName: "Codex"),
            RunningApplication(bundleIdentifier: "com.apple.finder", localizedName: "Finder")
        ])

        XCTAssertTrue(provider.isCodexRunning())
    }

    func testReturnsFalseWhenCodexIsAbsent() {
        let provider = ProcessStatusProvider(applications: [
            RunningApplication(bundleIdentifier: "com.apple.finder", localizedName: "Finder")
        ])

        XCTAssertFalse(provider.isCodexRunning())
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `swift test --filter ProcessStatusProviderTests`

Expected: FAIL because provider types do not exist.

- [ ] **Step 3: Implement process detection**

```swift
// Sources/CodexUsageShared/ProcessStatusProvider.swift
import AppKit
import Foundation

public struct RunningApplication: Equatable, Sendable {
    public var bundleIdentifier: String?
    public var localizedName: String?

    public init(bundleIdentifier: String?, localizedName: String?) {
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
    }
}

public struct ProcessStatusProvider: Sendable {
    private let applicationsProvider: @Sendable () -> [RunningApplication]

    public init(applications: [RunningApplication]) {
        self.applicationsProvider = { applications }
    }

    public init() {
        self.applicationsProvider = {
            NSWorkspace.shared.runningApplications.map {
                RunningApplication(bundleIdentifier: $0.bundleIdentifier, localizedName: $0.localizedName)
            }
        }
    }

    public func isCodexRunning() -> Bool {
        applicationsProvider().contains { app in
            app.bundleIdentifier == "com.openai.codex" ||
            app.localizedName == "Codex" ||
            app.localizedName == "Codex.app"
        }
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift test --filter ProcessStatusProviderTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexUsageShared/ProcessStatusProvider.swift Tests/CodexUsageSharedTests/ProcessStatusProviderTests.swift
git commit -m "feat: detect Codex process status"
```

## Task 7: Implement the Native Messaging Host

**Files:**
- Create: `Sources/CodexUsageNativeHost/main.swift`
- Create: `Sources/CodexUsageNativeHostCore/NativeHostController.swift`
- Test: `Tests/CodexUsageNativeHostCoreTests/NativeHostControllerTests.swift`

- [ ] **Step 1: Write failing controller tests**

```swift
import XCTest
@testable import CodexUsageShared
@testable import CodexUsageNativeHostCore

final class NativeHostControllerTests: XCTestCase {
    func testGetStatusIncludesCodexRunningAndLastUsage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = UsageCacheStore(directory: directory)
        let controller = NativeHostController(cache: cache, processStatus: ProcessStatusProvider(applications: [
            RunningApplication(bundleIdentifier: "com.openai.codex", localizedName: "Codex")
        ]))

        let event = try controller.handle(NativeRequest(type: .getStatus, requestId: "1", payload: nil))

        XCTAssertEqual(event.type, .status)
        XCTAssertEqual(event.requestId, "1")
        XCTAssertEqual(event.codexRunning, true)
        XCTAssertEqual(event.lastUsage?.status, .noData)
    }

    func testUsageUpdatePersistsPayload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = UsageCacheStore(directory: directory)
        let controller = NativeHostController(cache: cache, processStatus: ProcessStatusProvider(applications: []))
        let snapshot = UsageSnapshot.status(.pausedCodexNotRunning)

        _ = try controller.handle(NativeRequest(type: .usageUpdate, requestId: "2", payload: snapshot))

        XCTAssertEqual(try cache.load(), snapshot)
    }
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `swift test --filter NativeHostControllerTests`

Expected: FAIL because native host controller does not exist.

- [ ] **Step 3: Implement controller and entry point**

```swift
// Sources/CodexUsageNativeHostCore/NativeHostController.swift
import CodexUsageShared
import Foundation

public struct NativeHostController {
    private let cache: UsageCacheStore
    private let processStatus: ProcessStatusProvider

    public init(cache: UsageCacheStore = UsageCacheStore(), processStatus: ProcessStatusProvider = ProcessStatusProvider()) {
        self.cache = cache
        self.processStatus = processStatus
    }

    public func handle(_ request: NativeRequest) throws -> NativeEvent {
        switch request.type {
        case .getStatus:
            return NativeEvent(
                type: .status,
                requestId: request.requestId,
                codexRunning: processStatus.isCodexRunning(),
                lastUsage: try cache.load(),
                reason: nil,
                message: nil
            )
        case .usageUpdate:
            guard let payload = request.payload else {
                return NativeEvent(type: .error, requestId: request.requestId, codexRunning: nil, lastUsage: nil, reason: nil, message: "missing payload")
            }
            try cache.save(payload)
            return NativeEvent(type: .ack, requestId: request.requestId, codexRunning: nil, lastUsage: payload, reason: nil, message: nil)
        }
    }
}
```

```swift
// Sources/CodexUsageNativeHost/main.swift
import CodexUsageNativeHostCore
import CodexUsageShared
import Foundation

let controller = NativeHostController()
let input = FileHandle.standardInput
let output = FileHandle.standardOutput

while true {
    let lengthData = input.readData(ofLength: 4)
    if lengthData.count == 0 { break }
    if lengthData.count != 4 { break }

    let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    let payload = input.readData(ofLength: Int(length))
    guard payload.count == Int(length) else { break }

    do {
        var framed = Data()
        framed.append(lengthData)
        framed.append(payload)
        let request = try NativeMessageCodec.decode(NativeRequest.self, from: framed)
        let event = try controller.handle(request)
        output.write(try NativeMessageCodec.encode(event))
    } catch {
        let event = NativeEvent(type: .error, requestId: nil, codexRunning: nil, lastUsage: nil, reason: nil, message: String(describing: error))
        output.write(try NativeMessageCodec.encode(event))
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `swift test --filter NativeHostControllerTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodexUsageNativeHost Sources/CodexUsageNativeHostCore Tests/CodexUsageNativeHostCoreTests/NativeHostControllerTests.swift
git commit -m "feat: add native messaging host"
```

## Task 8: Implement Extension Parser Against the Redacted Fixture

**Files:**
- Create: `extension/src/usageParser.js`
- Create: `extension/src/usageTypes.js`
- Test: `extension/test/usageParser.test.mjs`

- [ ] **Step 1: Write failing parser tests**

```js
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { parseUsageSource } from "../src/usageParser.js";

test("parses redacted usage source fixture", () => {
  const jsonPath = "extension/fixtures/usage-source-v1.redacted.json";
  const textPath = "extension/fixtures/usage-source-v1.redacted.txt";
  const expected = JSON.parse(fs.readFileSync("extension/fixtures/usage-expected-v1.json", "utf8"));
  const source = fs.existsSync(jsonPath)
    ? fs.readFileSync(jsonPath, "utf8")
    : fs.readFileSync(textPath, "utf8");

  const parsed = parseUsageSource(source);

  assert.equal(parsed.schemaVersion, expected.schemaVersion);
  assert.equal(parsed.status, "ok");
  assert.equal(parsed.fiveHour.remainingPercent, expected.fiveHour.remainingPercent);
  assert.equal(parsed.fiveHour.resetLabel, expected.fiveHour.resetLabel);
  assert.equal(parsed.weekly.remainingPercent, expected.weekly.remainingPercent);
  assert.equal(parsed.weekly.resetLabel, expected.weekly.resetLabel);
});
```

- [ ] **Step 2: Run parser test and verify it fails**

Run: `node --test extension/test/usageParser.test.mjs`

Expected: FAIL because `usageParser.js` does not exist.

- [ ] **Step 3: Implement parser helpers**

```js
// extension/src/usageTypes.js
export function okUsagePayload({ fiveHour, weekly }) {
  return {
    schemaVersion: 1,
    status: "ok",
    fiveHour,
    weekly,
    updatedAt: new Date().toISOString(),
    source: {
      parserVersion: "1",
      sourceKind: "chatgpt-web-usage"
    }
  };
}

export function statusPayload(status) {
  return {
    schemaVersion: 1,
    status,
    updatedAt: new Date().toISOString(),
    source: {
      parserVersion: "1",
      sourceKind: "chatgpt-web-usage"
    }
  };
}
```

```js
// extension/src/usageParser.js
import { okUsagePayload, statusPayload } from "./usageTypes.js";

export function parseUsageSource(sourceText) {
  const source = String(sourceText);
  const fromJson = tryParseJsonUsage(source);
  if (fromJson) return okUsagePayload(fromJson);

  const fromText = tryParseTextUsage(source);
  if (fromText) return okUsagePayload(fromText);

  return statusPayload("parse_failed");
}

function tryParseJsonUsage(source) {
  try {
    const value = JSON.parse(source);
    const text = JSON.stringify(value);
    return tryParseTextUsage(text);
  } catch {
    return null;
  }
}

function tryParseTextUsage(text) {
  const normalized = text.replace(/\s+/g, " ");
  const five = normalized.match(/(?:5h|5-hour|five.?hour)[^0-9]{0,80}([0-9]{1,3})%[^A-Za-z0-9]{0,80}([A-Za-z]{3,9}|[0-9]{1,2}:[0-9]{2})/i);
  const weekly = normalized.match(/(?:weekly|week)[^0-9]{0,80}([0-9]{1,3})%[^A-Za-z0-9]{0,80}([A-Za-z]{3,9}|[0-9]{1,2}:[0-9]{2})/i);
  if (!five || !weekly) return null;

  return {
    fiveHour: {
      remainingPercent: clampPercent(Number(five[1])),
      resetLabel: five[2]
    },
    weekly: {
      remainingPercent: clampPercent(Number(weekly[1])),
      resetLabel: weekly[2]
    }
  };
}

function clampPercent(value) {
  return Math.max(0, Math.min(100, value));
}
```

- [ ] **Step 4: Run parser tests and adjust only against the committed fixture**

Run: `node --test extension/test/usageParser.test.mjs`

Expected: PASS after the parser matches the redacted fixture from Task 1. If the regex fallback does not match the fixture, replace `tryParseJsonUsage` or `tryParseTextUsage` with explicit field extraction based on `docs/usage-source-contract.md`; keep the test fixture unchanged.

- [ ] **Step 5: Commit**

```bash
git add extension/src/usageParser.js extension/src/usageTypes.js extension/test/usageParser.test.mjs extension/fixtures/usage-expected-v1.json
git commit -m "feat: parse Codex usage source"
```

## Task 9: Implement Chrome Extension Native Client and Refresh Flow

**Files:**
- Create: `extension/manifest.json`
- Create: `extension/src/nativeClient.js`
- Create: `extension/src/usageFetcher.js`
- Create: `extension/src/background.js`
- Test: `extension/test/nativeClient.test.mjs`

- [ ] **Step 1: Write a native client unit test**

```js
import test from "node:test";
import assert from "node:assert/strict";
import { createRequestTracker } from "../src/nativeClient.js";

test("tracks pending native requests by request id", async () => {
  const tracker = createRequestTracker();
  const promise = tracker.waitFor("abc");
  tracker.resolve({ requestId: "abc", type: "status", codexRunning: true });

  await assert.doesNotReject(promise);
  assert.equal((await promise).codexRunning, true);
});
```

- [ ] **Step 2: Run test and verify it fails**

Run: `node --test extension/test/nativeClient.test.mjs`

Expected: FAIL because `nativeClient.js` does not exist.

- [ ] **Step 3: Implement extension files**

```json
{
  "manifest_version": 3,
  "name": "Codex Usage Companion",
  "version": "0.1.0",
  "description": "Reads ChatGPT Codex usage and sends parsed results to the local menu bar app.",
  "permissions": ["alarms", "idle", "nativeMessaging", "storage"],
  "host_permissions": ["https://chatgpt.com/*", "https://*.openai.com/*"],
  "background": {
    "service_worker": "src/background.js",
    "type": "module"
  }
}
```

```js
// extension/src/nativeClient.js
export const HOST_NAME = "com.starshards.codex_usage";

export function createRequestTracker() {
  const pending = new Map();
  return {
    waitFor(requestId) {
      return new Promise((resolve, reject) => {
        pending.set(requestId, { resolve, reject });
      });
    },
    resolve(message) {
      const entry = pending.get(message.requestId);
      if (!entry) return;
      pending.delete(message.requestId);
      entry.resolve(message);
    },
    rejectAll(error) {
      for (const entry of pending.values()) entry.reject(error);
      pending.clear();
    }
  };
}

export function createNativeClient(chromeRuntime = chrome.runtime) {
  const tracker = createRequestTracker();
  let port = null;

  function connect() {
    port = chromeRuntime.connectNative(HOST_NAME);
    port.onMessage.addListener((message) => tracker.resolve(message));
    port.onDisconnect.addListener(() => {
      tracker.rejectAll(new Error("native host disconnected"));
      port = null;
    });
  }

  async function request(message) {
    if (!port) connect();
    const requestId = message.requestId ?? crypto.randomUUID();
    const response = tracker.waitFor(requestId);
    port.postMessage({ ...message, requestId });
    return response;
  }

  return { connect, request };
}
```

```js
// extension/src/usageFetcher.js
export async function fetchUsageSource(sourceUrl) {
  const response = await fetch(sourceUrl, {
    method: "GET",
    credentials: "include",
    cache: "no-store"
  });

  if (response.status === 401 || response.status === 403) {
    return { status: "not_logged_in", text: "" };
  }

  if (!response.ok) {
    return { status: "network_failed", text: "" };
  }

  return { status: "ok", text: await response.text() };
}
```

```js
// extension/src/background.js
import { createNativeClient } from "./nativeClient.js";
import { fetchUsageSource } from "./usageFetcher.js";
import { parseUsageSource } from "./usageParser.js";
import { USAGE_SOURCE_URL } from "./usageSourceConfig.js";
import { statusPayload } from "./usageTypes.js";

const nativeClient = createNativeClient();

chrome.runtime.onInstalled.addListener(async () => {
  chrome.idle.setDetectionInterval(60);
  await chrome.alarms.create("codex-usage-refresh", { periodInMinutes: 1 });
  nativeClient.connect();
  refreshUsage("installed");
});

chrome.runtime.onStartup.addListener(() => {
  nativeClient.connect();
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "codex-usage-refresh") refreshUsage("alarm");
});

chrome.idle.onStateChanged.addListener((state) => {
  if (state === "active") refreshUsage("idle_active");
});

async function refreshUsage(reason) {
  const status = await nativeClient.request({ type: "get_status" });
  if (!status.codexRunning) {
    await nativeClient.request({ type: "usage_update", payload: statusPayload("paused_codex_not_running") });
    return;
  }

  const fetched = await fetchUsageSource(USAGE_SOURCE_URL);
  const payload = fetched.status === "ok" ? parseUsageSource(fetched.text) : statusPayload(fetched.status);
  payload.reason = reason;
  await nativeClient.request({ type: "usage_update", payload });
}
```

- [ ] **Step 4: Run extension tests**

Run: `npm run test:extension`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add extension
git commit -m "feat: add Chrome usage companion extension"
```

## Task 10: Add Menu Bar App UI

**Files:**
- Create: `Sources/CodexUsageMenubar/main.swift`
- Create: `Sources/CodexUsageMenubar/AppDelegate.swift`
- Create: `Sources/CodexUsageMenubar/StatusItemController.swift`
- Create: `Sources/CodexUsageMenubar/TwoLineStatusView.swift`

- [ ] **Step 1: Add app entry point**

```swift
// Sources/CodexUsageMenubar/main.swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 2: Add app delegate**

```swift
// Sources/CodexUsageMenubar/AppDelegate.swift
import AppKit
import CodexUsageShared

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(cache: UsageCacheStore())
        statusController?.start()
    }
}
```

- [ ] **Step 3: Add two-line status view**

```swift
// Sources/CodexUsageMenubar/TwoLineStatusView.swift
import AppKit

final class TwoLineStatusView: NSView {
    private let firstLine = NSTextField(labelWithString: "Codex --")
    private let secondLine = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(lines: [String]) {
        firstLine.stringValue = lines.indices.contains(0) ? lines[0] : ""
        secondLine.stringValue = lines.indices.contains(1) ? lines[1] : ""
        needsLayout = true
    }

    private func setup() {
        wantsLayer = true
        for label in [firstLine, secondLine] {
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
            label.textColor = .labelColor
            label.alignment = .right
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }

        NSLayoutConstraint.activate([
            firstLine.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            firstLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            firstLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            secondLine.topAnchor.constraint(equalTo: firstLine.bottomAnchor, constant: -1),
            secondLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            secondLine.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}
```

- [ ] **Step 4: Add status item controller**

```swift
// Sources/CodexUsageMenubar/StatusItemController.swift
import AppKit
import CodexUsageShared

final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 86)
    private let statusView = TwoLineStatusView(frame: NSRect(x: 0, y: 0, width: 82, height: 22))
    private let cache: UsageCacheStore
    private var timer: Timer?

    init(cache: UsageCacheStore) {
        self.cache = cache
    }

    func start() {
        if let button = statusItem.button {
            button.addSubview(statusView)
            statusView.frame = button.bounds
            statusView.autoresizingMask = [.width, .height]
        }
        statusItem.menu = makeMenu()
        reloadFromCache()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.reloadFromCache()
        }
    }

    private func reloadFromCache() {
        let snapshot = (try? cache.load()) ?? .status(.noData)
        statusView.update(lines: UsageFormatter.menuBarLines(for: snapshot))
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        let openUsage = NSMenuItem(title: "Open ChatGPT Usage Page", action: #selector(openUsagePage), keyEquivalent: "")
        openUsage.target = self
        menu.addItem(openUsage)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func refreshNow() {
        reloadFromCache()
    }

    @objc private func openUsagePage() {
        NSWorkspace.shared.open(URL(string: "https://chatgpt.com/codex/")!)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 5: Build the app**

Run: `swift build`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodexUsageMenubar
git commit -m "feat: add menu bar display"
```

## Task 11: Add Native Host Registration and Build Scripts

**Files:**
- Create: `native-host/com.starshards.codex_usage.json.template`
- Create: `scripts/register-native-host.sh`
- Create: `scripts/build-app.sh`
- Create: `scripts/smoke-native-host.mjs`

- [ ] **Step 1: Add Native Messaging manifest template**

```json
{
  "name": "com.starshards.codex_usage",
  "description": "Codex Usage native messaging host",
  "path": "__HOST_BINARY_PATH__",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://__EXTENSION_ID__/"]
}
```

- [ ] **Step 2: Add registration script**

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/register-native-host.sh <chrome-extension-id>" >&2
  exit 64
fi

EXTENSION_ID="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST_BINARY="$ROOT/.build/debug/CodexUsageNativeHost"
TARGET_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
TARGET_FILE="$TARGET_DIR/com.starshards.codex_usage.json"

swift build --product CodexUsageNativeHost
mkdir -p "$TARGET_DIR"
sed \
  -e "s#__HOST_BINARY_PATH__#$HOST_BINARY#g" \
  -e "s#__EXTENSION_ID__#$EXTENSION_ID#g" \
  "$ROOT/native-host/com.starshards.codex_usage.json.template" > "$TARGET_FILE"

echo "Wrote $TARGET_FILE"
```

- [ ] **Step 3: Add build app script**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist/Codex Usage.app"
MACOS="$DIST/Contents/MacOS"

swift build --product CodexUsageMenubar
rm -rf "$DIST"
mkdir -p "$MACOS"
cp "$ROOT/.build/debug/CodexUsageMenubar" "$MACOS/Codex Usage"
cat > "$DIST/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Codex Usage</string>
  <key>CFBundleIdentifier</key>
  <string>com.starshards.codex-usage</string>
  <key>CFBundleName</key>
  <string>Codex Usage</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST
echo "$DIST"
```

- [ ] **Step 4: Add smoke test script**

```js
// scripts/smoke-native-host.mjs
import { spawn } from "node:child_process";

const child = spawn(".build/debug/CodexUsageNativeHost", [], { stdio: ["pipe", "pipe", "inherit"] });
const payload = Buffer.from(JSON.stringify({ type: "get_status", requestId: "smoke" }));
const length = Buffer.alloc(4);
length.writeUInt32LE(payload.length);
child.stdin.write(Buffer.concat([length, payload]));
child.stdin.end();

const chunks = [];
child.stdout.on("data", chunk => chunks.push(chunk));
child.on("close", code => {
  const output = Buffer.concat(chunks);
  if (output.length < 4) process.exit(1);
  const size = output.readUInt32LE(0);
  const message = JSON.parse(output.subarray(4, 4 + size).toString("utf8"));
  if (message.type !== "status") process.exit(1);
  console.log(JSON.stringify(message, null, 2));
  process.exit(code);
});
```

- [ ] **Step 5: Make scripts executable and run smoke checks**

Run:

```bash
chmod +x scripts/register-native-host.sh scripts/build-app.sh
swift build
node scripts/smoke-native-host.mjs
scripts/build-app.sh
```

Expected: `swift build` passes, smoke script prints a `status` message, and `dist/Codex Usage.app` exists.

- [ ] **Step 6: Commit**

```bash
git add native-host scripts
git commit -m "chore: add local build and native host scripts"
```

## Task 12: Wire Manual Refresh, Wake Refresh, and Details Menu

**Files:**
- Modify: `Sources/CodexUsageMenubar/StatusItemController.swift`
- Create: `Sources/CodexUsageMenubar/WakeObserver.swift`

- [ ] **Step 1: Add wake observer**

```swift
// Sources/CodexUsageMenubar/WakeObserver.swift
import AppKit

final class WakeObserver {
    private var token: NSObjectProtocol?
    private let onWake: () -> Void

    init(onWake: @escaping () -> Void) {
        self.onWake = onWake
    }

    func start() {
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [onWake] _ in
            onWake()
        }
    }

    deinit {
        if let token {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }
}
```

- [ ] **Step 2: Update status controller with detail menu and wake reload**

Modify `StatusItemController` so it stores the last snapshot and rebuilds menu labels:

```swift
private var wakeObserver: WakeObserver?
private var lastSnapshot: UsageSnapshot = .status(.noData)

func start() {
    if let button = statusItem.button {
        button.addSubview(statusView)
        statusView.frame = button.bounds
        statusView.autoresizingMask = [.width, .height]
    }
    reloadFromCache()
    statusItem.menu = makeMenu()
    wakeObserver = WakeObserver { [weak self] in self?.reloadFromCache() }
    wakeObserver?.start()
    timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
        self?.reloadFromCache()
    }
}

private func reloadFromCache() {
    lastSnapshot = (try? cache.load()) ?? .status(.noData)
    statusView.update(lines: UsageFormatter.menuBarLines(for: lastSnapshot))
    statusItem.menu = makeMenu()
}
```

Update `makeMenu()` with a version that includes details:

```swift
private func makeMenu() -> NSMenu {
    let menu = NSMenu()
    if let fiveHour = lastSnapshot.fiveHour {
        menu.addItem(NSMenuItem(title: "5h: \(fiveHour.remainingPercent)% until \(fiveHour.resetLabel)", action: nil, keyEquivalent: ""))
    }
    if let weekly = lastSnapshot.weekly {
        menu.addItem(NSMenuItem(title: "Weekly: \(weekly.remainingPercent)% until \(weekly.resetLabel)", action: nil, keyEquivalent: ""))
    }
    menu.addItem(NSMenuItem(title: "Status: \(lastSnapshot.status.rawValue)", action: nil, keyEquivalent: ""))
    menu.addItem(.separator())
    let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
    refresh.target = self
    menu.addItem(refresh)
    let openUsage = NSMenuItem(title: "Open ChatGPT Usage Page", action: #selector(openUsagePage), keyEquivalent: "")
    openUsage.target = self
    menu.addItem(openUsage)
    menu.addItem(.separator())
    let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
    quit.target = self
    menu.addItem(quit)
    return menu
}
```

- [ ] **Step 3: Build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodexUsageMenubar
git commit -m "feat: add menu details and wake reload"
```

## Task 13: End-to-End Manual Verification

**Files:**
- Create: `docs/manual-verification.md`

- [ ] **Step 1: Write verification checklist**

```markdown
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
```

- [ ] **Step 2: Run automated checks**

Run:

```bash
swift test
npm run test:extension
swift build
node scripts/smoke-native-host.mjs
```

Expected: all pass.

- [ ] **Step 3: Run manual checks**

Follow `docs/manual-verification.md`. Record observed results in the same file under a `## Results` heading.

- [ ] **Step 4: Commit**

```bash
git add docs/manual-verification.md
git commit -m "docs: add manual verification checklist"
```

## Task 14: Final Privacy and Scope Audit

**Files:**
- Modify: `docs/manual-verification.md`

- [ ] **Step 1: Search for forbidden persisted data**

Run:

```bash
rg -n "cookie|authorization|bearer|id_token|accessToken|rawHtml|rawResponse" .
```

Expected: matches only redaction code, tests, and documentation. No committed fixture should contain real secrets or raw authenticated response bodies.

- [ ] **Step 2: Verify git state**

Run:

```bash
git status --short
git log --oneline --max-count=10
```

Expected: working tree clean after any verification-result commit.

- [ ] **Step 3: Record final result**

Append to `docs/manual-verification.md`:

```markdown
## Final Audit

- Automated tests:
- Native host smoke test:
- Manual Chrome extension check:
- Secret/raw-response scan:
- Remaining known limitation:
```

Fill each line with the command result or observed outcome.

- [ ] **Step 4: Commit final audit**

```bash
git add docs/manual-verification.md
git commit -m "docs: record final verification"
```

## Handoff Notes

Implementation should use TDD for each shared Swift module and extension parser module. UI tasks can be built after model/cache/protocol tests pass. The highest-risk task is source discovery; complete it first and stop if it cannot produce a redacted fixture with both quota windows.

Do not push, publish, sign, notarize, or create a Chrome Web Store package in v1.
