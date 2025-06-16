import Foundation

/// Represents a build system.
public protocol Builder {

    /// List of known products. Is used for packaging operations such as generating Apple frameworks.
    var products: [Product] { get set }

    /// Environment variables for a given target.
    var environment: ((Target) -> [String:String])? { get set }
    
    /// Output directory path.
    /// Default value is "build/<sdk>.arch1(-arch2)".
    /// 
    /// Parameters:
    ///     - target: Target to find.
    ///
    /// - Returns: the relative output directory path of a given target.
    func outputDirectoryPath(for target: Target) -> String

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
    
    var environment: ((Target) -> [String:String])? {
        get { nil }
        set {     }
    }
    
    func outputDirectoryPath(for target: Target) -> String {
        "build/\(target.systemName.rawValue).\(target.architectures.map({ $0.rawValue }).joined(separator: "-"))"
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
