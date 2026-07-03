import AppKit
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
