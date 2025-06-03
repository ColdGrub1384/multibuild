/// Information about the target SDK and architecture(s) we're compiling to.
public struct Target: Hashable {

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
}