import Foundation

public enum UsageFormatter {
    public static func menuBarLines(for snapshot: UsageSnapshot) -> [String] {
        guard snapshot.status == .ok else {
            return fallbackLines(for: snapshot.status)
        }

        if let fiveHour = snapshot.fiveHour, let weekly = snapshot.weekly {
            let labelWidth = max("5h".count, "1w".count)
            let percentWidth = max("\(fiveHour.remainingPercent)%".count, "\(weekly.remainingPercent)%".count)

            return [
                menuBarLine(windowLabel: "5h", percent: fiveHour.remainingPercent, resetLabel: fiveHour.resetLabel, labelWidth: labelWidth, percentWidth: percentWidth),
                menuBarLine(windowLabel: "1w", percent: weekly.remainingPercent, resetLabel: weekly.resetLabel, labelWidth: labelWidth, percentWidth: percentWidth)
            ]
        }

        if let weekly = snapshot.weekly {
            return ["ChatGPT", "1w \(weekly.remainingPercent)% \(weekly.resetLabel)"]
        }

        return fallbackLines(for: .noData)
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
            return ["ChatGPT --", ""]
        case .ok:
            return ["ChatGPT --", ""]
        }
    }
}

private extension String {
    func rightPadded(to width: Int) -> String {
        guard count < width else { return self }
        return self + String(repeating: " ", count: width - count)
    }
}
