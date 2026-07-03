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
            "\(fiveHour.resetLabel)  \(fiveHour.remainingPercent)% 5h",
            "\(weekly.resetLabel) \(weekly.remainingPercent)% 7d"
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
