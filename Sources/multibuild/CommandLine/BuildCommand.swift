import ArgumentParser
import Foundation

/// Argument parser for a ``BuildPlan`` based program.
/// 
/// ```
/// USAGE: build-command --root <root> [--list-targets] [--force-configure] [--target <target> ...]
///
/// OPTIONS:
///  --root <root>           Common root directory of projects
///  --list-targets          List supported compilation targets
///  -f, --force-configure   Force regenerating Makefiles and other configurations
///  -t, --target <target>   Specify a target to build
///  -h, --help              Show help information.
/// ```
public struct BuildCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(commandName: URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0]).lastPathComponent, abstract: "Command line interface for building your projects.")

    /// Common root directory of project.
    @Option(name: [.customLong("root")], help: "Common root directory of projects")
    public var rootDirectory: String

    /// List supported compilation targets.
    @Flag(name: [.customLong("list-targets")], help: "List supported compilation targets")
    public var listTargets = false

    /// Force regenerating configuration files. 
    @Flag(name: [.short, .customLong("force-configure")], help: "Force regenerating Makefiles and other configurations")
    public var forceConfigure = false

    /// Targets to compile to. If none is passed, will compile for all supported targets. 
    @Option(name: [.short, .customLong("target")], help: "Specify a target to build")
    public var targets: [Target] = []

    public init() {}

    public mutating func run() throws {}
}
