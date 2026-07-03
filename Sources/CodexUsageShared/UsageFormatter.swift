import Foundation

public enum UsageFormatter {
    public static func menuBarLines(for snapshot: UsageSnapshot) -> [String] {
        guard snapshot.status == .ok,
              let fiveHour = snapshot.fiveHour,
              let weekly = snapshot.weekly
        else {
            return fallbackLines(for: snapshot.status)
        }

        let labelWidth = max("5h".count, "7d".count)
        let percentWidth = max("\(fiveHour.remainingPercent)%".count, "\(weekly.remainingPercent)%".count)

        return [
            menuBarLine(windowLabel: "5h", percent: fiveHour.remainingPercent, resetLabel: fiveHour.resetLabel, labelWidth: labelWidth, percentWidth: percentWidth),
            menuBarLine(windowLabel: "7d", percent: weekly.remainingPercent, resetLabel: weekly.resetLabel, labelWidth: labelWidth, percentWidth: percentWidth)
        ]
    }

    private static func menuBarLine(windowLabel: String, percent: Int, resetLabel: String, labelWidth: Int, percentWidth: Int) -> String {
        "\(windowLabel.rightPadded(to: labelWidth)) \("\(percent)%".rightPadded(to: percentWidth)) \(resetLabel)"
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
    func rightPadded(to width: Int) -> String {
        guard count < width else { return self }
        return self + String(repeating: " ", count: width - count)
    }
}
