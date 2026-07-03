import AppKit

@MainActor
final class WakeObserver {
    private var token: NSObjectProtocol?
    private let onWake: @MainActor @Sendable () -> Void

    init(onWake: @escaping @MainActor @Sendable () -> Void) {
        self.onWake = onWake
    }

    func start() {
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [onWake] _ in
            Task { @MainActor in
                onWake()
            }
        }
    }

    func stop() {
        if let token {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            self.token = nil
        }
    }
}
