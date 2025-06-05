import Foundation

/// A build plan to execute at the launch of the program. It also builds the xcode frameworks if supported.
///
/// You can create a type conforming to `BuildPlan` and mark it with the `@main` attribute to automatically compile the defined projects.
/// Example:
/// ```swift
/// 
///     @main
///     struct Plan: BuildPlan {
///         var supportedTargets: [Target] {
///             Platform.apple.supportedTargets
///         }
/// 
///         var bundleIdentifierPrefix: String {
///             "app.pyto"
///         }
/// 
///         var project: Project {
///             Project(...)
///             Project(...)
///         }
///     }
/// 
/// ```
public protocol BuildPlan {

    /// Targets to compile the projects to.
    var supportedTargets: [Target] { get }

    /// Bundle identifier prefix for Apple frameworks.
    var bundleIdentifierPrefix: String { get }

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
        let plan = Self()
        try plan.project.compile(for: plan.supportedTargets)
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
}