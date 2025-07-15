import ArgumentParser
import Foundation

fileprivate extension Project.Version {
    
    // v3.14.0b2
    var string: String {
        switch self {
        case .custom(let version):
            return version
        case .git(let version, _):
            return version
        }
    }
    
    // v3140b2
    var plainString: String {
        string.replacingOccurrences(of: ".", with: "")
    }
    
    // 3.14
    var minor: String {
        var minor = minorPlain
        minor.insert(".", at: minor.index(minor.startIndex, offsetBy: 1))
        return minor
    }
    
    // 314
    var minorPlain: String {
        var version = plainString
        if version.hasPrefix("v") {
            version.removeFirst()
        }
        
        return String(version.prefix(3))
    }
}

/// Information about the target SDK and architecture(s) we're compiling to.
/// This type is used to construct the compilers target triple.
///
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
    ///     This behaviour can be changed by setting the `universalBuild` parameter of the ``compile`` functions in ``Project``.
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
    
    /// Python platform name for native extensions, contained in the suffix of the shared objects as well as the wheels.
    ///
    /// This is not standard Python and does not correspond necessarily to `sys.platform`.
    /// The standard Python implementation adds `simulator` as an abi flag for iOS (after the architecture), here is it added directly to the platform after an underscore (`_`) but `sys.platform` is always expected to be just `ios`.
    ///
    /// ## Possible values:
    ///
    /// ### iOS
    /// - ABI: `ios` (`iphoneos`), `ios_simulator` (`iphonesimulator`), `ios_macabi` (`maccatalyst`)
    /// - Platform: `ios`
    ///
    /// ### watchOS
    /// - ABI: `watchos` (`watchos`), `watchos_simulator` (`watchsimulator`)
    /// - Platform: `watchos`
    ///
    /// ### tvOS
    /// - ABI: `tvos` (`appletvos`), `tvos_simulator` (`appletvsimulator`)
    public var soabiPlatform: String {
        switch systemName {
        case .iphoneos:
            "ios"
        case .iphonesimulator:
            "ios_simulator"
        case .maccatalyst:
            "ios_macabi"
        case .watchos:
            "watchos"
        case .watchsimulator:
            "watchos_simulator"
        case .appletvos:
            "tvos"
        case .appletvsimulator:
            "tvos_simulator"
        }
    }
    
    public func pythonSOABI(version: Project.Version) -> String {
        "cpython-\(version.minorPlain)-\(soabiPlatform.replacingOccurrences(of: "_", with: "-"))"
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

    /// Initializes from a command line argument.
    ///
    /// - Parameters:
    ///     - argument: Format: `<system_name>.<arch1>(-[arch2... ])`
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
