import ArgumentParser

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