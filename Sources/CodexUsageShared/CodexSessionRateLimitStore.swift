import Foundation

public struct CodexSessionRateLimitStore: Sendable {
    public let sessionsDirectory: URL
    public let timeZone: TimeZone

    public init(
        sessionsDirectory: URL = CodexSessionRateLimitStore.defaultSessionsDirectory(),
        timeZone: TimeZone = .current
    ) {
        self.sessionsDirectory = sessionsDirectory
        self.timeZone = timeZone
    }

    public static func defaultSessionsDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    public func loadLatestSnapshot() -> UsageSnapshot? {
        let files = sessionFiles()
        for file in files.prefix(30) {
            guard let event = latestRateLimitEvent(in: file) else { continue }
            return snapshot(from: event)
        }
        return nil
    }

    private func sessionFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [(url: URL, modifiedAt: Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            files.append((url, values?.contentModificationDate ?? .distantPast))
        }

        return files
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .map(\.url)
    }

    private func latestRateLimitEvent(in file: URL) -> CodexSessionEvent? {
        guard let contents = try? String(contentsOf: file, encoding: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        for line in contents.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard let data = String(line).data(using: .utf8),
                  let event = try? decoder.decode(CodexSessionEvent.self, from: data),
                  event.type == "event_msg",
                  event.payload.type == "token_count",
                  let rateLimits = event.payload.rateLimits,
                  !rateLimits.isSparkLimit
            else {
                continue
            }
            return event
        }
        return nil
    }

    private func snapshot(from event: CodexSessionEvent) -> UsageSnapshot? {
        guard let rateLimits = event.payload.rateLimits,
              let timestamp = parseTimestamp(event.timestamp)
        else {
            return nil
        }

        let fiveHour = rateLimits.windows.first { $0.windowMinutes == 300 }
        let weekly = rateLimits.windows.first { $0.windowMinutes == 10_080 }
        guard fiveHour != nil || weekly != nil else {
            return nil
        }

        return UsageSnapshot(
            schemaVersion: 1,
            status: .ok,
            fiveHour: fiveHour.map { quotaWindow(from: $0, labelKind: .time) },
            weekly: weekly.map { quotaWindow(from: $0, labelKind: .date) },
            updatedAt: timestamp,
            source: UsageSource(sourceKind: "codex-session-rate-limits")
        )
    }

    private func quotaWindow(from window: CodexRateLimitWindow, labelKind: ResetLabelKind) -> QuotaWindow {
        let resetAt = Date(timeIntervalSince1970: TimeInterval(window.resetsAt))
        return QuotaWindow(
            remainingPercent: clampPercent(100 - window.usedPercent),
            resetLabel: labelKind == .time ? formatTime(resetAt) : formatMonthDay(resetAt),
            resetAt: resetAt
        )
    }

    private func clampPercent(_ value: Double) -> Int {
        max(0, min(100, Int(value.rounded())))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatMonthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func parseTimestamp(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private enum ResetLabelKind {
        case time
        case date
    }
}

private struct CodexSessionEvent: Decodable {
    var timestamp: String
    var type: String
    var payload: Payload

    struct Payload: Decodable {
        var type: String
        var rateLimits: CodexRateLimits?

        enum CodingKeys: String, CodingKey {
            case type
            case rateLimits = "rate_limits"
        }
    }
}

private struct CodexRateLimits: Decodable {
    var limitId: String?
    var limitName: String?
    var primary: CodexRateLimitWindow?
    var secondary: CodexRateLimitWindow?

    var isSparkLimit: Bool {
        limitId == "codex_bengalfox" || limitName == "GPT-5.3-Codex-Spark"
    }

    var windows: [CodexRateLimitWindow] {
        [primary, secondary].compactMap { $0 }
    }

    enum CodingKeys: String, CodingKey {
        case limitId = "limit_id"
        case limitName = "limit_name"
        case primary
        case secondary
    }
}

private struct CodexRateLimitWindow: Decodable {
    var usedPercent: Double
    var windowMinutes: Int?
    var resetsAt: Int

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetsAt = "resets_at"
    }
}
