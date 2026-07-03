import CodexUsageNativeHostCore
import CodexUsageShared
import Foundation

let controller = NativeHostController()
let input = FileHandle.standardInput
let output = FileHandle.standardOutput

while true {
    let lengthData = input.readData(ofLength: 4)
    if lengthData.count == 0 { break }
    if lengthData.count != 4 { break }

    let length = Int(lengthData[0]) |
        (Int(lengthData[1]) << 8) |
        (Int(lengthData[2]) << 16) |
        (Int(lengthData[3]) << 24)
    let payload = input.readData(ofLength: length)
    guard payload.count == length else { break }

    do {
        var framed = Data()
        framed.append(lengthData)
        framed.append(payload)
        let request = try NativeMessageCodec.decode(NativeRequest.self, from: framed)
        let event = try controller.handle(request)
        output.write(try NativeMessageCodec.encode(event))
    } catch {
        let event = NativeEvent(
            type: .error,
            requestId: nil,
            codexRunning: nil,
            lastUsage: nil,
            reason: nil,
            message: String(describing: error)
        )
        if let data = try? NativeMessageCodec.encode(event) {
            output.write(data)
        }
    }
}
