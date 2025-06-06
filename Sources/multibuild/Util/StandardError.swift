import Foundation

internal class StandardErrorStream: TextOutputStream {
    func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

internal var StandardError = StandardErrorStream()