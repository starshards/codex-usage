import AppKit
import CodexUsageShared
import XCTest
@testable import CodexUsageMenubar

final class TwoLineStatusViewTests: XCTestCase {
    @MainActor
    func testLabelsAreLeftAlignedForColumnLayout() {
        let view = TwoLineStatusView(frame: NSRect(x: 0, y: 0, width: 82, height: 22))
        let labels = view.subviews.compactMap { $0 as? NSTextField }

        XCTAssertEqual(labels.map { $0.alignment }, [.left, .left])
    }
}

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testRequestRefreshLoadsLocalCodexRateLimits() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessionsDirectory = directory.appendingPathComponent("sessions", isDirectory: true)
        let sessionDay = sessionsDirectory.appendingPathComponent("2026/07/03", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDay, withIntermediateDirectories: true)
        try #"{"timestamp":"2026-07-03T16:57:45.035Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":63,"window_minutes":300,"resets_at":1783099357},"secondary":{"used_percent":98,"window_minutes":10080,"resets_at":1783391609},"plan_type":"prolite"}}}"#
            .write(to: sessionDay.appendingPathComponent("rollout.jsonl"), atomically: true, encoding: .utf8)
        let cache = UsageCacheStore(directory: directory.appendingPathComponent("cache", isDirectory: true))
        let controller = StatusItemController(
            cache: cache,
            localRateLimits: CodexSessionRateLimitStore(
                sessionsDirectory: sessionsDirectory,
                timeZone: TimeZone(identifier: "Asia/Shanghai")!
            ),
            processStatus: ProcessStatusProvider(applications: [
                RunningApplication(bundleIdentifier: "com.openai.codex", localizedName: "Codex")
            ])
        )

        try controller.requestRefresh(reason: "manual")

        let snapshot = try cache.load()
        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 37)
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 2)
        XCTAssertEqual(snapshot.source.sourceKind, "codex-session-rate-limits")
    }
}
