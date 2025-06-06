import Foundation

/// Command line interface for building your projects.
///
/// You can create a type conforming to ``BuildPlan`` and mark it with the `@main` attribute to automatically compile the defined projects.
/// Example:
/// ```swift
/// @main
/// struct Plan: BuildPlan {
///     var supportedTargets = Platform.apple.supportedTargets
///     var bundleIdentifierPrefix = "app.pyto"
/// 
///     var project: Project {
///         Project(...)
///         Project(...)
///     }
/// }
/// ```
/// 
/// When executed, the projects will compile for ``BuildPlan/supportedTargets``.
/// See ``BuildCommand`` for more command line usage information.
public protocol BuildPlan {

    /// Targets to compile the projects to.
    var supportedTargets: [Target] { get set }

    /// Bundle identifier prefix for Apple frameworks.
    var bundleIdentifierPrefix: String { get set }

    /// Root directory passed to the command line arguments via the '-r' or '--root' flag.
    /// Can be used as a reference to find your projects.
    var rootURL: URL { get }

    /// The value of the --force-configure flag passed to the command line arguments.
    /// Determines wether configuration files should be regenerated even if they exist.
    var forceConfigure: Bool { get }

    /// A project to compile. You can concatenate them to create a combined project.
    @PlanBuilder
    var project: Project { get }

    /// Get the build information for the requested project.
    /// 
    /// - Parameters:
    ///     - projectName: Project directory's base name.
    /// 
    /// - Returns: Information about the build directory.
    func build(for projectName: String) -> Build?

    /// Compiles the projects.
    static func main() throws -> Void

    init()
}

public extension BuildPlan {

    init() {
        self.init()
    }

    static func main() throws -> Void {
        if ProcessInfo.processInfo.arguments.contains("-h") || ProcessInfo.processInfo.arguments.contains("--help") {
            print(BuildCommand.helpMessage(), to: &StandardError)
            exit(0)
        }

        let plan = Self()
        try plan.project.compile(for: plan.supportedTargets, forceConfigure: plan.forceConfigure)
        if plan.supportedTargets.contains(where: { $0.isApple }) {
            for dep in plan.project.dependencies {
                var proj = dep.project
                if proj == nil, let name = dep.name {
                    proj = ProjectNames[name]
                }
                _ = try proj?.build?.createXcodeFrameworks(bundleIdentifierPrefix: plan.bundleIdentifierPrefix)
            }
        }
        exit(0)
    }

    func build(for projectName: String) -> Build? {
        ProjectNames[projectName]?.build
    }

    var rootURL: URL {
        do {
            let command = try BuildCommand.parse()
            return URL(string: command.rootDirectory, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))!
        } catch {
            print(BuildCommand.fullMessage(for: error), to: &StandardError)
            exit(1)
        }
    }

    var forceConfigure: Bool {
        do {
            let command = try BuildCommand.parse()
            return command.forceConfigure
        } catch {
            print(BuildCommand.fullMessage(for: error), to: &StandardError)
            exit(1)
        }
    }
}