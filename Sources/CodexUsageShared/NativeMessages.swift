import Foundation

public enum NativeRequestType: String, Codable, Sendable {
    case getStatus = "get_status"
    case usageUpdate = "usage_update"
}

public struct NativeRequest: Codable, Equatable, Sendable {
    public var type: NativeRequestType
    public var requestId: String
    public var payload: UsageSnapshot?

    public init(type: NativeRequestType, requestId: String, payload: UsageSnapshot?) {
        self.type = type
        self.requestId = requestId
        self.payload = payload
    }
}

public enum NativeEventType: String, Codable, Sendable {
    case status
    case ack
    case refreshNow = "refresh_now"
    case error
}

public struct NativeEvent: Codable, Equatable, Sendable {
    public var type: NativeEventType
    public var requestId: String?
    public var codexRunning: Bool?
    public var lastUsage: UsageSnapshot?
    public var reason: String?
    public var message: String?

    public init(
        type: NativeEventType,
        requestId: String?,
        codexRunning: Bool?,
        lastUsage: UsageSnapshot?,
        reason: String?,
        message: String?
    ) {
        self.type = type
        self.requestId = requestId
        self.codexRunning = codexRunning
        self.lastUsage = lastUsage
        self.reason = reason
        self.message = message
    }
}
