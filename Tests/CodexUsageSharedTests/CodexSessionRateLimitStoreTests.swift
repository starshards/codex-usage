import XCTest
@testable import CodexUsageShared

final class CodexSessionRateLimitStoreTests: XCTestCase {
    func testLoadsLatestRateLimitsFromCodexSessionJsonl() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessionDirectory = root.appendingPathComponent("2026/07/03", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        let sessionFile = sessionDirectory.appendingPathComponent("rollout.jsonl")
        try [
            #"{"timestamp":"2026-07-03T16:56:00.000Z","type":"event_msg","payload":{"type":"other"}}"#,
            #"{"timestamp":"2026-07-03T16:57:45.035Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":63,"window_minutes":300,"resets_at":1783099357},"secondary":{"used_percent":98,"window_minutes":10080,"resets_at":1783391609},"plan_type":"prolite"}}}"#
        ].joined(separator: "\n").write(to: sessionFile, atomically: true, encoding: .utf8)
        let store = CodexSessionRateLimitStore(
            sessionsDirectory: root,
            timeZone: TimeZone(identifier: "Asia/Shanghai")!
        )

        let snapshot = try XCTUnwrap(store.loadLatestSnapshot())

        XCTAssertEqual(snapshot.status, .ok)
        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 37)
        XCTAssertEqual(snapshot.fiveHour?.resetLabel, "01:22")
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 2)
        XCTAssertEqual(snapshot.weekly?.resetLabel, "7月7日")
        XCTAssertEqual(snapshot.source.sourceKind, "codex-session-rate-limits")
        XCTAssertEqual(snapshot.updatedAt.timeIntervalSince1970, 1_783_097_865.035, accuracy: 0.001)
    }
}
