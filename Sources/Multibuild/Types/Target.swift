import ArgumentParser
import Foundation

/// Information about the target SDK and architecture(s) we're compiling to.
/// Can be added to a ``Platform`` or to another target with the `+` operator.
public struct Target: Hashable, ExpressibleByArgument {

    /// Architecture name.
    public enum Architecture: String {
        
        /// armv7k
        case armv7k

        /// arm64_32
        case arm64_32

        /// arm64
        case arm64

        /// x86_64
        case x86_64
    }

    /// Target SDK name.
    public enum SystemName: String {

        /// iOS
        case iphoneos

        /// iOS Simulator
        case iphonesimulator

        /// watchOS
        case watchos

        /// watchOS Simulator
        case watchsimulator

        /// tvOS
        case appletvos

        /// tvOS Simulator
        case appletvsimulator

        /// Mac Catalyst
        case maccatalyst
    }

    /// The name of the target SDK.
    public var systemName: SystemName

    /// List of architectures supported by the target.
    ///
    /// - Note: 
    ///     By default, compiling to a target with multiple architectures produces single architecture binaries. 
    ///     That means the project compiles once per architecture and then it merges the libraries. 
    ///     This behaviour can be changed by setting the `universalBuild` parameter of the ``Project/compile`` function.
    public var architectures: [Architecture]

    /// Target triple. For example, `arm64-apple-ios13.0`.
    public var triple: String? {
        let pipe = Pipe()
        let process = Process()
        process.standardOutput = pipe
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.environment = targetEnvironment(for: self)
        process.environment?["BUILD_SCRIPT"] = Bundle.module.path(forResource: "Environment/print_triple", ofType: "sh")
        for (key, value) in ProcessInfo.processInfo.environment {
            process.environment?[key] = value
        }
        process.arguments = [
            Bundle.module.url(forResource: "Environment/environment", withExtension: "sh")!.path,
            "3.14"
        ]

        process.launch()
        process.waitUntilExit()
        
        return String(data: pipe.fileHandleForReading.availableData, encoding: .utf8)?.replacingOccurrences(of: "\n", with: "")
    }

    /// URL of the sysroot directory.
    public var sdkURL: URL? {
        let pipe = Pipe()
        let process = Process()
        process.standardOutput = pipe
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.environment = targetEnvironment(for: self)
        process.environment?["BUILD_SCRIPT"] = Bundle.module.path(forResource: "Environment/print_sdk_path", ofType: "sh")
        for (key, value) in ProcessInfo.processInfo.environment {
            process.environment?[key] = value
        }
        process.arguments = [
            Bundle.module.url(forResource: "Environment/environment", withExtension: "sh")!.path,
            "3.14"
        ]

        process.launch()
        process.waitUntilExit()

        if let path = String(data: pipe.fileHandleForReading.availableData, encoding: .utf8)?.replacingOccurrences(of: "\n", with: "") {
            return URL(fileURLWithPath: path)
        } else {
            return nil
        }
    }

    /// Returns `true` if targetting an Apple SDK.
    public var isApple: Bool {
        [
            SystemName.iphoneos,
            SystemName.iphonesimulator,
            SystemName.watchos,
            SystemName.watchsimulator,
            SystemName.appletvos,
            SystemName.appletvsimulator,
            SystemName.maccatalyst
        ].contains(systemName)
    }

    /// Initializes a target.
    /// 
    /// - Parameters:
    ///     - systemName: Target SDK name.
    ///     - architectures: List of architectures supported by the target.
    public init(systemName: SystemName, architectures: [Architecture]) {
        self.systemName = systemName
        self.architectures = architectures
    }

    public init?(argument: String) {
        let comps = argument.components(separatedBy: ".")
        guard comps.count == 2, let systemName = SystemName(rawValue: comps[0]) else {
            return nil
        }
        
        var archs = [Architecture]()
        for arch in comps[1].components(separatedBy: "-") {
            guard let architecture = Architecture(rawValue: arch) else {
                return nil
            }
            archs.append(architecture)
        }
        
        self.systemName = systemName
        self.architectures = archs
    }

    static func +(lhs: Target, rhs: Target) -> Platform {
        Platform(supportedTargets: [lhs, rhs])
    }
}