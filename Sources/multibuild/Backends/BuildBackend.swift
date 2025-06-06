import Foundation

/// Represents a backend build system.
public protocol BuildBackend {

    /// Products of the compilation.
    var products: [Product] { get set }

    /// Output directory path.
    /// 
    /// Parameters:
    ///     - target: Target to find.
    ///
    /// - Returns: the relative output directory path of a given target.
    func outputDirectoryPath(for target: Target) -> String

    /// Additional environment variables to set during compilation.
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

internal extension BuildBackend {
    
    func defaultEnvironment(for target: Target) -> [String:String] {
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
}