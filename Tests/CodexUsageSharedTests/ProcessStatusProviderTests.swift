import XCTest
@testable import CodexUsageShared

final class ProcessStatusProviderTests: XCTestCase {
    func testDetectsCodexByBundleIdentifierOrName() {
        let provider = ProcessStatusProvider(applications: [
            RunningApplication(bundleIdentifier: "com.openai.codex", localizedName: "Codex"),
            RunningApplication(bundleIdentifier: "com.apple.finder", localizedName: "Finder")
        ])

        XCTAssertTrue(provider.isCodexRunning())
    }

    func testReturnsFalseWhenCodexIsAbsent() {
        let provider = ProcessStatusProvider(applications: [
            RunningApplication(bundleIdentifier: "com.apple.finder", localizedName: "Finder")
        ])

        XCTAssertFalse(provider.isCodexRunning())
    }

    func testDetectsRenamedChatGPTApplicationByLocalizedName() {
        let provider = ProcessStatusProvider(applications: [
            RunningApplication(bundleIdentifier: nil, localizedName: "ChatGPT")
        ])

        XCTAssertTrue(provider.isCodexRunning())
    }
}
