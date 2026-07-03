import XCTest
@testable import CodexUsageShared

final class RefreshRequestStoreTests: XCTestCase {
    func testSavesAndConsumesRefreshRequest() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = RefreshRequestStore(directory: directory)
        let requestedAt = Date(timeIntervalSince1970: 1_783_090_000)

        let request = try store.requestRefresh(reason: "manual", id: "refresh-1", requestedAt: requestedAt)

        XCTAssertEqual(request.id, "refresh-1")
        XCTAssertEqual(try store.consumePendingRequest(), request)
        XCTAssertNil(try store.consumePendingRequest())
    }
}
