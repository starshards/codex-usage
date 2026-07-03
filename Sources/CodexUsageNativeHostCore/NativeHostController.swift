import CodexUsageShared
import Foundation

public struct NativeHostController {
    private let cache: UsageCacheStore
    private let processStatus: ProcessStatusProvider

    public init(cache: UsageCacheStore = UsageCacheStore(), processStatus: ProcessStatusProvider = ProcessStatusProvider()) {
        self.cache = cache
        self.processStatus = processStatus
    }

    public func handle(_ request: NativeRequest) throws -> NativeEvent {
        switch request.type {
        case .getStatus:
            return NativeEvent(
                type: .status,
                requestId: request.requestId,
                codexRunning: processStatus.isCodexRunning(),
                lastUsage: try cache.load(),
                reason: nil,
                message: nil
            )

        case .usageUpdate:
            guard let payload = request.payload else {
                return NativeEvent(
                    type: .error,
                    requestId: request.requestId,
                    codexRunning: nil,
                    lastUsage: nil,
                    reason: nil,
                    message: "missing payload"
                )
            }

            try cache.save(payload)
            return NativeEvent(
                type: .ack,
                requestId: request.requestId,
                codexRunning: nil,
                lastUsage: payload,
                reason: nil,
                message: nil
            )
        }
    }
}
