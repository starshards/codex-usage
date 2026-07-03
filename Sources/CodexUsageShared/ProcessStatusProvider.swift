import AppKit
import Foundation

public struct RunningApplication: Equatable, Sendable {
    public var bundleIdentifier: String?
    public var localizedName: String?

    public init(bundleIdentifier: String?, localizedName: String?) {
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
    }
}

public struct ProcessStatusProvider: Sendable {
    private let applicationsProvider: @Sendable () -> [RunningApplication]

    public init(applications: [RunningApplication]) {
        self.applicationsProvider = { applications }
    }

    public init() {
        self.applicationsProvider = {
            NSWorkspace.shared.runningApplications.map {
                RunningApplication(bundleIdentifier: $0.bundleIdentifier, localizedName: $0.localizedName)
            }
        }
    }

    public func isCodexRunning() -> Bool {
        applicationsProvider().contains { app in
            app.bundleIdentifier == "com.openai.codex" ||
                app.localizedName == "Codex" ||
                app.localizedName == "Codex.app"
        }
    }
}
