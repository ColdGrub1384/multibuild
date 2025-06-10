import Foundation

/// Represents a build system.
public protocol Builder {

    /// List of known products. Is used for packaging operations such as generating Apple frameworks.
    var products: [Product] { get set }

    /// Output directory path.
    /// Default value is "build/<sdk>.arch1(-arch2)".
    /// 
    /// Parameters:
    ///     - target: Target to find.
    ///
    /// - Returns: the relative output directory path of a given target.
    func outputDirectoryPath(for target: Target) -> String

    /// Additional environment variables to set during compilation.
    /// Default value is an empty dictionary.
    /// 
    /// - Note: Will be pasted as is and evaluated by bash. 
    ///
    /// - Parameters:
    ///     - target: The target we're compiling to while needing the environment variables.
    /// 
    /// - Returns: A dictionary of environment variable names as keys and their respective value. 
    func environment(for target: Target) -> [String:String]

    /// Build script for given target.
    /// 
    /// - Parameters:
    ///     - target: Target we're compiling to.
    ///     - forceConfigure: Force regenerating configuration files.
    /// 
    /// - Returns: A bash script as plain code.
    func buildScript(for target: Target, forceConfigure: Bool) -> String
}

public extension Builder {
    func outputDirectoryPath(for target: Target) -> String {
        "build/\(target.systemName.rawValue).\(target.architectures.map({ $0.rawValue }).joined(separator: "-"))"
    }

    func environment(for target: Target) -> [String : String] {
        [:]
    }
}

internal extension Builder {

    func defaultEnvironment(for target: Target) -> [String:String] {
        targetEnvironment(for: target)
    }
}

internal func targetEnvironment(for target: Target) -> [String:String] {
    var flags = [String:String]()
    switch target.systemName {
        case .iphoneos, .iphonesimulator:
            flags = [
                "IOSARCH": target.architectures.map({ $0.rawValue }).joined(separator: " "),
                "IOSSDK": target.systemName.rawValue
            ]
        case .watchos, .watchsimulator:
            flags = [
                "WATCHOSARCH": target.architectures.map({ $0.rawValue }).joined(separator: " "),
                "WATCHOSSDK": target.systemName.rawValue
            ]
        case .appletvos, .appletvsimulator:
            flags = [
                "TVOSARCH": target.architectures.map({ $0.rawValue }).joined(separator: " "),
                "TVOSSDK": target.systemName.rawValue
            ]
        case .maccatalyst:
            flags = [
                "MAC_CATALYST": target.architectures.map({ $0.rawValue }).joined(separator: " ")
            ]
    }
    return flags
}