import Foundation

public enum NativeMessageCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(value)
        var data = Data()
        data.append(UInt8(payload.count & 0xff))
        data.append(UInt8((payload.count >> 8) & 0xff))
        data.append(UInt8((payload.count >> 16) & 0xff))
        data.append(UInt8((payload.count >> 24) & 0xff))
        data.append(payload)
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard data.count >= 4 else { throw CodecError.truncatedLength }
        let length = Int(data[0]) |
            (Int(data[1]) << 8) |
            (Int(data[2]) << 16) |
            (Int(data[3]) << 24)
        let payload = data.dropFirst(4)
        guard payload.count == length else { throw CodecError.lengthMismatch }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: payload)
    }

    public enum CodecError: Error, Equatable {
        case truncatedLength
        case lengthMismatch
    }
}
