/// A platform contains all the supported targets of a project.
/// Can be added to another platform or a ``Target`` can be added to a platform with the `+` operator.
public struct Platform {

    /// The list of the supported target.
    public var supportedTargets: [Target]

    /// iOS arm64 and iOS Simulator arm64 + x86_64
    public static let iOS = Self(supportedTargets: [
        Target(systemName: .iphoneos, architectures: [.arm64]),
        Target(systemName: .iphonesimulator, architectures: [.arm64, .x86_64])
    ])

    /// watchOS armv7k + arm64_32 + arm64 and watchOS Simulator arm64 + x86_64
    public static let watchOS = Self(supportedTargets: [
        Target(systemName: .watchos, architectures: [.armv7k, .arm64_32, .arm64]),
        Target(systemName: .watchsimulator, architectures: [.arm64, .x86_64])
    ])

    /// tvOS arm64 and tvOS Simulator arm64 + x86_64
    public static let tvOS = Self(supportedTargets: [
        Target(systemName: .appletvos, architectures: [.arm64]),
        Target(systemName: .appletvsimulator, architectures: [.arm64, .x86_64])
    ])

    /// mac Catalyst arm64 + x86_64
    public static let macCatalyst = Self(supportedTargets: [
        Target(systemName: .maccatalyst, architectures: [.arm64, .x86_64]),
    ])

    /// iOS, watchOS, tvOS and mac Catalyst combined.
    public static let apple = 
        Self.iOS +
        Self.watchOS +
        Self.tvOS +
        Self.macCatalyst

    static func +(lhs: Platform, rhs: Platform) -> Platform {
        Platform(supportedTargets: Array(Set(lhs.supportedTargets+rhs.supportedTargets)))
    }
}