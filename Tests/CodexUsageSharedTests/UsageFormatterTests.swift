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
