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

    func testUsageUpdateAcknowledgesButDoesNotOverwriteLocalCache() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = UsageCacheStore(directory: directory)
        let controller = NativeHostController(cache: cache, processStatus: ProcessStatusProvider(applications: []))
        let localSnapshot = UsageSnapshot(
            schemaVersion: 1,
            status: .ok,
            fiveHour: QuotaWindow(remainingPercent: 91, resetLabel: "01:55", resetAt: nil),
            weekly: QuotaWindow(remainingPercent: 96, resetLabel: "7月11日", resetAt: nil),
            updatedAt: Date(timeIntervalSince1970: 1_783_169_520),
            source: UsageSource(sourceKind: "codex-session-rate-limits")
        )
        try cache.save(localSnapshot)
        let chromeSnapshot = UsageSnapshot.status(.parseFailed, updatedAt: Date(timeIntervalSince1970: 1_783_169_580))

        let event = try controller.handle(NativeRequest(type: .usageUpdate, requestId: "2", payload: chromeSnapshot))

        XCTAssertEqual(event.type, .ack)
        XCTAssertEqual(event.requestId, "2")
        XCTAssertEqual(try cache.load(), localSnapshot)
    }

    func testConsumesPendingRefreshRequestAsRefreshNowEvent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let refreshRequests = RefreshRequestStore(directory: directory)
        _ = try refreshRequests.requestRefresh(reason: "manual", id: "refresh-1")
        let controller = NativeHostController(
            cache: UsageCacheStore(directory: directory),
            refreshRequests: refreshRequests,
            processStatus: ProcessStatusProvider(applications: [])
        )

        let event = try controller.consumeRefreshRequest()

        XCTAssertEqual(event?.type, .refreshNow)
        XCTAssertEqual(event?.reason, "manual")
        XCTAssertNil(event?.requestId)
        XCTAssertNil(try controller.consumeRefreshRequest())
    }
}
