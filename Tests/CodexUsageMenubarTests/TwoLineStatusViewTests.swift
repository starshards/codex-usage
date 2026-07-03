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
    func testRequestRefreshWritesPendingRefreshRequest() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let refreshRequests = RefreshRequestStore(directory: directory)
        let controller = StatusItemController(
            cache: UsageCacheStore(directory: directory),
            refreshRequests: refreshRequests
        )

        try controller.requestRefresh(reason: "manual")

        XCTAssertEqual(try refreshRequests.consumePendingRequest()?.reason, "manual")
    }
}
