import AppKit
import CodexUsageShared

@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 86)
    private let statusView = TwoLineStatusView(frame: NSRect(x: 0, y: 0, width: 82, height: 22))
    private let cache: UsageCacheStore
    private var timer: Timer?
    private var wakeObserver: WakeObserver?
    private var lastSnapshot: UsageSnapshot = .status(.noData)

    init(cache: UsageCacheStore) {
        self.cache = cache
    }

    func start() {
        if let button = statusItem.button {
            button.addSubview(statusView)
            statusView.frame = button.bounds
            statusView.autoresizingMask = [.width, .height]
        }
        reloadFromCache()
        statusItem.menu = makeMenu()
        wakeObserver = WakeObserver { [weak self] in self?.reloadFromCache() }
        wakeObserver?.start()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reloadFromCache()
            }
        }
    }

    private func reloadFromCache() {
        lastSnapshot = (try? cache.load()) ?? .status(.noData)
        statusView.update(lines: UsageFormatter.menuBarLines(for: lastSnapshot))
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        if let fiveHour = lastSnapshot.fiveHour {
            menu.addItem(NSMenuItem(title: "5h: \(fiveHour.remainingPercent)% until \(fiveHour.resetLabel)", action: nil, keyEquivalent: ""))
        }
        if let weekly = lastSnapshot.weekly {
            menu.addItem(NSMenuItem(title: "Weekly: \(weekly.remainingPercent)% until \(weekly.resetLabel)", action: nil, keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: "Status: \(lastSnapshot.status.rawValue)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        let openUsage = NSMenuItem(title: "Open ChatGPT Usage Page", action: #selector(openUsagePage), keyEquivalent: "")
        openUsage.target = self
        menu.addItem(openUsage)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func refreshNow() {
        reloadFromCache()
    }

    @objc private func openUsagePage() {
        NSWorkspace.shared.open(URL(string: "https://chatgpt.com/codex/cloud/settings/analytics?no_universal_links=1")!)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
