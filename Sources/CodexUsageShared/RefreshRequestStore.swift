import Foundation

public struct RefreshRequest: Codable, Equatable, Sendable {
    public var id: String
    public var reason: String
    public var requestedAt: Date

    public init(id: String, reason: String, requestedAt: Date) {
        self.id = id
        self.reason = reason
        self.requestedAt = requestedAt
    }
}

public struct RefreshRequestStore: Sendable {
    public let directory: URL
    public let fileName: String

    public init(directory: URL = UsageCacheStore.defaultDirectory(), fileName: String = "refresh-request.json") {
        self.directory = directory
        self.fileName = fileName
    }

    public func requestRefresh(reason: String, id: String = UUID().uuidString, requestedAt: Date = Date()) throws -> RefreshRequest {
        let request = RefreshRequest(id: id, reason: reason, requestedAt: requestedAt)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        let temp = directory.appendingPathComponent("\(fileName).tmp")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)
        try data.write(to: temp, options: [.atomic])
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: temp, to: url)
        return request
    }

    public func consumePendingRequest() throws -> RefreshRequest? {
        let url = directory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let request = try decoder.decode(RefreshRequest.self, from: data)
        try FileManager.default.removeItem(at: url)
        return request
    }
}
