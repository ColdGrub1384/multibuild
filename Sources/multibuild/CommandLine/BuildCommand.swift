import ArgumentParser
import Foundation

/// Argument parser for a ``BuildPlan`` based program.
/// 
/// ```
/// USAGE: build-command --root <root> [--force-configure]
///
/// OPTIONS:
///  -r, --root <root>       Common root directory of projects
///  -f, --force-configure   Force regenerating Makefiles and other configurations
///  -h, --help              Show help information.
/// ```
public struct BuildCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(abstract: "Command line interface for building your projects.")

    /// Common root directory of project.
    @Option(name: [.short, .customLong("root")], help: "Common root directory of projects")
    public var rootDirectory: String

    /// Force regenerating configuration files. 
    @Flag(name: [.short, .customLong("force-configure")], help: "Force regenerating Makefiles and other configurations")
    public var forceConfigure = false

    public init() {}

    public mutating func run() throws {}
}
