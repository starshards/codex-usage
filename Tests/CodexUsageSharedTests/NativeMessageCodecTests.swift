import XCTest
@testable import CodexUsageShared

final class NativeMessageCodecTests: XCTestCase {
    func testEncodesAndDecodesLengthPrefixedMessage() throws {
        let message = NativeRequest(type: .getStatus, requestId: "abc", payload: nil)
        let data = try NativeMessageCodec.encode(message)
        let decoded = try NativeMessageCodec.decode(NativeRequest.self, from: data)

        XCTAssertEqual(decoded.type, .getStatus)
        XCTAssertEqual(decoded.requestId, "abc")
    }

    func testDecodesIso8601UsageUpdatePayloadFromExtension() throws {
        let json = """
        {"type":"usage_update","requestId":"abc","payload":{"schemaVersion":1,"status":"ok","fiveHour":{"remainingPercent":83,"resetLabel":"01:22","resetAt":"2026-07-04T01:22:38Z"},"weekly":{"remainingPercent":9,"resetLabel":"Tue","resetAt":"2026-07-07T10:33:30Z"},"updatedAt":"2026-07-03T23:30:00Z","source":{"parserVersion":"1","sourceKind":"chatgpt-wham-usage"}}}
        """
        let payload = Data(json.utf8)
        var data = Data()
        data.append(UInt8(payload.count & 0xff))
        data.append(UInt8((payload.count >> 8) & 0xff))
        data.append(UInt8((payload.count >> 16) & 0xff))
        data.append(UInt8((payload.count >> 24) & 0xff))
        data.append(payload)

        let decoded = try NativeMessageCodec.decode(NativeRequest.self, from: data)

        XCTAssertEqual(decoded.payload?.updatedAt, ISO8601DateFormatter().date(from: "2026-07-03T23:30:00Z"))
        XCTAssertEqual(decoded.payload?.source.sourceKind, "chatgpt-wham-usage")
    }
}
