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
