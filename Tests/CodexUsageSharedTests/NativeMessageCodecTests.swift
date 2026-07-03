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
}
