import Foundation

public enum UsageFormatter {
    public static func menuBarLines(for snapshot: UsageSnapshot) -> [String] {
        guard snapshot.status == .ok,
              let fiveHour = snapshot.fiveHour,
              let weekly = snapshot.weekly
        else {
            return fallbackLines(for: snapshot.status)
        }

        let resetWidth = max(fiveHour.resetLabel.count, weekly.resetLabel.count)
        let percentWidth = max("\(fiveHour.remainingPercent)%".count, "\(weekly.remainingPercent)%".count, 4)

        return [
            menuBarLine(resetLabel: fiveHour.resetLabel, percent: fiveHour.remainingPercent, windowLabel: "5h", resetWidth: resetWidth, percentWidth: percentWidth),
            menuBarLine(resetLabel: weekly.resetLabel, percent: weekly.remainingPercent, windowLabel: "7d", resetWidth: resetWidth, percentWidth: percentWidth)
        ]
    }

    private static func menuBarLine(resetLabel: String, percent: Int, windowLabel: String, resetWidth: Int, percentWidth: Int) -> String {
        "\(resetLabel.leftPadded(to: resetWidth)) \("\(percent)%".leftPadded(to: percentWidth)) \(windowLabel)"
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

private extension String {
    func leftPadded(to width: Int) -> String {
        guard count < width else { return self }
        return String(repeating: " ", count: width - count) + self
    }
}
