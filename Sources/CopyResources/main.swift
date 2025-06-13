import Foundation

let inputFile = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[1])
let outputFile = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[2])

if !FileManager.default.fileExists(atPath: outputFile.deletingLastPathComponent().path) {
    try! FileManager.default.createDirectory(at: outputFile.deletingLastPathComponent(), withIntermediateDirectories: true)
}

if FileManager.default.fileExists(atPath: outputFile.path) {
    try! FileManager.default.removeItem(at: outputFile)
}

try! FileManager.default.copyItem(at: inputFile, to: outputFile)