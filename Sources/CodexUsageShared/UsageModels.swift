import Foundation

public enum UsageStatus: String, Codable, Equatable, Sendable {
    case ok
    case pausedCodexNotRunning = "paused_codex_not_running"
    case notLoggedIn = "not_logged_in"
    case networkFailed = "network_failed"
    case parseFailed = "parse_failed"
    case noData = "no_data"
}

public struct QuotaWindow: Codable, Equatable, Sendable {
    public var remainingPercent: Int
    public var resetLabel: String
    public var resetAt: Date?

    public init(remainingPercent: Int, resetLabel: String, resetAt: Date?) {
        self.remainingPercent = remainingPercent
        self.resetLabel = resetLabel
        self.resetAt = resetAt
    }
}

public struct UsageSource: Codable, Equatable, Sendable {
    public var parserVersion: String
    public var sourceKind: String

    public init(parserVersion: String = "1", sourceKind: String = "chatgpt-wham-usage") {
        self.parserVersion = parserVersion
        self.sourceKind = sourceKind
    }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var status: UsageStatus
    public var fiveHour: QuotaWindow?
    public var weekly: QuotaWindow?
    public var updatedAt: Date
    public var source: UsageSource

    public static func ok(fiveHour: QuotaWindow, weekly: QuotaWindow, updatedAt: Date) -> UsageSnapshot {
        UsageSnapshot(
            schemaVersion: 1,
            status: .ok,
            fiveHour: fiveHour,
            weekly: weekly,
            updatedAt: updatedAt,
            source: UsageSource()
        )
    }

    public static func status(_ status: UsageStatus, updatedAt: Date = Date(timeIntervalSince1970: 0)) -> UsageSnapshot {
        UsageSnapshot(
            schemaVersion: 1,
            status: status,
            fiveHour: nil,
            weekly: nil,
            updatedAt: updatedAt,
            source: UsageSource()
        )
    }
}
