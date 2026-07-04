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

    func testIgnoresSparkRateLimitsInLatestSessionFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessionDirectory = root.appendingPathComponent("2026/07/03", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        let sessionFile = sessionDirectory.appendingPathComponent("rollout.jsonl")
        try [
            #"{"timestamp":"2026-07-03T16:57:45.035Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":63,"window_minutes":300,"resets_at":1783099357},"secondary":{"used_percent":98,"window_minutes":10080,"resets_at":1783391609},"plan_type":"prolite"}}}"#,
            #"{"timestamp":"2026-07-03T18:05:28.927Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex_bengalfox","limit_name":"GPT-5.3-Codex-Spark","primary":{"used_percent":0,"window_minutes":300,"resets_at":1783119899},"secondary":{"used_percent":0,"window_minutes":10080,"resets_at":1783565235},"plan_type":"prolite"}}}"#
        ].joined(separator: "\n").write(to: sessionFile, atomically: true, encoding: .utf8)
        let store = CodexSessionRateLimitStore(
            sessionsDirectory: root,
            timeZone: TimeZone(identifier: "Asia/Shanghai")!
        )

        let snapshot = try XCTUnwrap(store.loadLatestSnapshot())

        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 37)
        XCTAssertEqual(snapshot.fiveHour?.resetLabel, "01:22")
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 2)
        XCTAssertEqual(snapshot.weekly?.resetLabel, "7月7日")
        XCTAssertEqual(snapshot.updatedAt.timeIntervalSince1970, 1_783_097_865.035, accuracy: 0.001)
    }

    func testSkipsLatestSessionFileWhenItOnlyHasSparkRateLimits() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessionDirectory = root.appendingPathComponent("2026/07/03", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        let olderSessionFile = sessionDirectory.appendingPathComponent("older.jsonl")
        let newerSparkOnlyFile = sessionDirectory.appendingPathComponent("newer.jsonl")
        try #"{"timestamp":"2026-07-03T16:57:45.035Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":63,"window_minutes":300,"resets_at":1783099357},"secondary":{"used_percent":98,"window_minutes":10080,"resets_at":1783391609},"plan_type":"prolite"}}}"#
            .write(to: olderSessionFile, atomically: true, encoding: .utf8)
        try #"{"timestamp":"2026-07-03T18:05:28.927Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex_bengalfox","limit_name":"GPT-5.3-Codex-Spark","primary":{"used_percent":0,"window_minutes":300,"resets_at":1783119899},"secondary":{"used_percent":0,"window_minutes":10080,"resets_at":1783565235},"plan_type":"prolite"}}}"#
            .write(to: newerSparkOnlyFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: olderSessionFile.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: newerSparkOnlyFile.path)
        let store = CodexSessionRateLimitStore(
            sessionsDirectory: root,
            timeZone: TimeZone(identifier: "Asia/Shanghai")!
        )

        let snapshot = try XCTUnwrap(store.loadLatestSnapshot())

        XCTAssertEqual(snapshot.fiveHour?.remainingPercent, 37)
        XCTAssertEqual(snapshot.weekly?.remainingPercent, 2)
        XCTAssertEqual(snapshot.updatedAt.timeIntervalSince1970, 1_783_097_865.035, accuracy: 0.001)
    }
}
