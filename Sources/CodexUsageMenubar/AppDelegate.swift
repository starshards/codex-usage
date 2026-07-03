import AppKit
import CodexUsageShared

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(cache: UsageCacheStore())
        statusController?.start()
    }
}
