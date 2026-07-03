import XCTest
@testable import CodexUsageShared

final class UsageFormatterTests: XCTestCase {
    func testFormatsCompleteUsageForMenuBar() {
        let snapshot = UsageSnapshot.ok(
            fiveHour: QuotaWindow(remainingPercent: 72, resetLabel: "18:30", resetAt: nil),
            weekly: QuotaWindow(remainingPercent: 41, resetLabel: "7/7", resetAt: nil),
            updatedAt: Date(timeIntervalSince1970: 1_783_084_500)
        )

        XCTAssertEqual(UsageFormatter.menuBarLines(for: snapshot), ["5h 72% 18:30", "1w 41% 7/7"])
    }

    func testAlignsOneDigitPercentInMenuBarColumns() {
        let snapshot = UsageSnapshot.ok(
            fiveHour: QuotaWindow(remainingPercent: 54, resetLabel: "01:22", resetAt: nil),
            weekly: QuotaWindow(remainingPercent: 4, resetLabel: "7/7", resetAt: nil),
            updatedAt: Date(timeIntervalSince1970: 1_783_084_500)
        )

        XCTAssertEqual(UsageFormatter.menuBarLines(for: snapshot), ["5h 54% 01:22", "1w 4%  7/7"])
    }

    func testFormatsFallbackStates() {
        XCTAssertEqual(UsageFormatter.menuBarLines(for: .status(.pausedCodexNotRunning)), ["Paused", ""])
        XCTAssertEqual(UsageFormatter.menuBarLines(for: .status(.notLoggedIn)), ["Login", ""])
        XCTAssertEqual(UsageFormatter.menuBarLines(for: .status(.noData)), ["Codex --", ""])
    }
}
