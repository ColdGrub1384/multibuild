import Foundation

/// Command line interface for building your projects.
///
/// You can create a type conforming to ``BuildPlan`` and decorate it with the `@main` attribute to automatically compile the defined projects.
/// Example:
/// ```swift
/// @main
/// struct Plan: BuildPlan {
///     var platform: Platform = .apple // .iOS + .macCatalyst + ...
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

    /// Supported targets of the project.
    var platform: Platform { get set }

    /// Bundle identifier prefix for Apple frameworks.
    var bundleIdentifierPrefix: String { get set }

    /// Root directory passed to the command line arguments via the '--root' option.
    /// Can be used as a reference to find your projects. (Defaults to working directory)
    var rootURL: URL { get }

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

internal extension BuildPlan {

    
}

public extension BuildPlan {

    init() {
        self.init()
    }

    static func main() throws -> Void {
        BuildCommand<Self>.main()
    }

    func build(for projectName: String) -> Build? {
        ProjectNames[projectName]?.build
    }

    var rootURL: URL {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        do {
            let command = try BuildCommand<Self>.parse()
            if let rootDir = command.rootDirectory {
                return URL(string: rootDir, relativeTo: cwd) ?? cwd
            } else {
                return cwd
            }
        } catch {
            return cwd
        }
    }
}