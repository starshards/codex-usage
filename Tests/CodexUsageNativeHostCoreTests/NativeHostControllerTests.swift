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
