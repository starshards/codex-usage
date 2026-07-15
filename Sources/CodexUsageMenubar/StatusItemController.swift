import AppKit
import CodexUsageShared

@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 86)
    private let statusView = TwoLineStatusView(frame: NSRect(x: 0, y: 0, width: 82, height: 22))
    private let cache: UsageCacheStore
    private let localRateLimits: CodexSessionRateLimitStore
    private let processStatus: ProcessStatusProvider
    private var timer: Timer?
    private var wakeObserver: WakeObserver?
    private var lastSnapshot: UsageSnapshot = .status(.noData)

    init(
        cache: UsageCacheStore,
        localRateLimits: CodexSessionRateLimitStore = CodexSessionRateLimitStore(),
        processStatus: ProcessStatusProvider = ProcessStatusProvider()
    ) {
        self.cache = cache
        self.localRateLimits = localRateLimits
        self.processStatus = processStatus
    }

    func start() {
        if let button = statusItem.button {
            button.addSubview(statusView)
            statusView.frame = button.bounds
            statusView.autoresizingMask = [.width, .height]
        }
        reloadUsage()
        statusItem.menu = makeMenu()
        wakeObserver = WakeObserver { [weak self] in
            try? self?.requestRefresh(reason: "wake")
        }
        wakeObserver?.start()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reloadUsage()
            }
        }
    }

    private func reloadUsage() {
        if !processStatus.isCodexRunning() {
            lastSnapshot = .status(.pausedCodexNotRunning)
        } else if let localSnapshot = localRateLimits.loadLatestSnapshot() {
            lastSnapshot = localSnapshot
            try? cache.save(localSnapshot)
        } else {
            lastSnapshot = (try? cache.load()) ?? .status(.noData)
        }
        statusView.update(lines: UsageFormatter.menuBarLines(for: lastSnapshot))
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        for title in Self.quotaMenuTitles(for: lastSnapshot) {
            menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
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

    static func quotaMenuTitles(for snapshot: UsageSnapshot) -> [String] {
        var titles: [String] = []
        if let fiveHour = snapshot.fiveHour {
            titles.append("5h: \(fiveHour.remainingPercent)% until \(fiveHour.resetLabel)")
        }
        if let weekly = snapshot.weekly {
            titles.append("Weekly: \(weekly.remainingPercent)% until \(weekly.resetLabel)")
        }
        return titles
    }

    @objc private func refreshNow() {
        try? requestRefresh(reason: "manual")
    }

    func requestRefresh(reason: String) throws {
        reloadUsage()
    }

    @objc private func openUsagePage() {
        NSWorkspace.shared.open(URL(string: "https://chatgpt.com/codex/cloud/settings/analytics?no_universal_links=1")!)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
