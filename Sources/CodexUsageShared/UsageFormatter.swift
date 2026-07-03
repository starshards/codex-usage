import Foundation

public enum UsageFormatter {
    public static func menuBarLines(for snapshot: UsageSnapshot) -> [String] {
        guard snapshot.status == .ok,
              let fiveHour = snapshot.fiveHour,
              let weekly = snapshot.weekly
        else {
            return fallbackLines(for: snapshot.status)
        }

        return [
            "5h \(fiveHour.remainingPercent)% \(fiveHour.resetLabel)",
            "W  \(weekly.remainingPercent)% \(weekly.resetLabel)"
        ]
    }

    private static func fallbackLines(for status: UsageStatus) -> [String] {
        switch status {
        case .pausedCodexNotRunning:
            return ["Paused", ""]
        case .notLoggedIn:
            return ["Login", ""]
        case .networkFailed, .parseFailed, .noData:
            return ["Codex --", ""]
        case .ok:
            return ["Codex --", ""]
        }
    }
}
