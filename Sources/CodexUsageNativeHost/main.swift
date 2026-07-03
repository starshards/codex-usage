import CodexUsageNativeHostCore
import CodexUsageShared
import Darwin
import Foundation

let controller = NativeHostController()
let input = FileHandle.standardInput
let output = FileHandle.standardOutput

func writeEvent(_ event: NativeEvent) {
    guard let data = try? NativeMessageCodec.encode(event) else { return }
    output.write(data)
}

func writeRefreshRequestIfNeeded() {
    do {
        if let event = try controller.consumeRefreshRequest() {
            writeEvent(event)
        }
    } catch {
        writeEvent(NativeEvent(
            type: .error,
            requestId: nil,
            codexRunning: nil,
            lastUsage: nil,
            reason: "refresh_request",
            message: String(describing: error)
        ))
    }
}

func readAndHandleMessage() -> Bool {
    let lengthData = input.readData(ofLength: 4)
    if lengthData.count == 0 { return false }
    if lengthData.count != 4 { return false }

    let length = Int(lengthData[0]) |
        (Int(lengthData[1]) << 8) |
        (Int(lengthData[2]) << 16) |
        (Int(lengthData[3]) << 24)
    let payload = input.readData(ofLength: length)
    guard payload.count == length else { return false }

    do {
        var framed = Data()
        framed.append(lengthData)
        framed.append(payload)
        let request = try NativeMessageCodec.decode(NativeRequest.self, from: framed)
        let event = try controller.handle(request)
        writeEvent(event)
    } catch {
        writeEvent(NativeEvent(
            type: .error,
            requestId: nil,
            codexRunning: nil,
            lastUsage: nil,
            reason: nil,
            message: String(describing: error)
        ))
    }
    return true
}

while true {
    writeRefreshRequestIfNeeded()

    var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
    let ready = poll(&descriptor, 1, 1000)

    if ready < 0 {
        if errno == EINTR { continue }
        break
    }
    if ready == 0 { continue }

    let hasInput = (descriptor.revents & Int16(POLLIN)) != 0
    let hungUp = (descriptor.revents & Int16(POLLHUP)) != 0
    if hasInput {
        if !readAndHandleMessage() { break }
    } else if hungUp {
        break
    }
}
