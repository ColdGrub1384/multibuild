import Foundation

/// Command line interface for building your projects.
///
/// You can create a type conforming to ``BuildPlan`` and mark it with the `@main` attribute to automatically compile the defined projects.
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

    /// Targets to compile the projects to.
    var platform: Platform { get set }

    /// Bundle identifier prefix for Apple frameworks.
    var bundleIdentifierPrefix: String { get set }

    /// Root directory passed to the command line arguments via the '--root' option.
    /// Can be used as a reference to find your projects.
    var rootURL: URL { get }

    /// The value of the --force-configure flag passed to the command line arguments.
    /// Determines wether configuration files should be regenerated even if they exist.
    var forceConfigure: Bool { get }

    /// Targets to build if they are passed to the command line arguments.
    /// If no target is passed, will compile for ``Platform``.
    var targets: [Target] { get }

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

    func listTargets() {
        var fusedTargets = [Target]()
        for target in platform.supportedTargets {
            if let i = fusedTargets.firstIndex(where: { $0.systemName == target.systemName }) {
                var modifiedTarget = fusedTargets.remove(at: i)
                for arch in target.architectures {
                    if !modifiedTarget.architectures.contains(arch) {
                        modifiedTarget.architectures.append(arch)
                    }
                }
                fusedTargets.insert(modifiedTarget, at: i)
            } else {
                fusedTargets.append(target)
            }
        }

        for target in fusedTargets {
            print("\(target.systemName.rawValue).\(target.architectures.map({ $0.rawValue }).joined(separator: "-"))")
        }
    }
}

public extension BuildPlan {

    init() {
        self.init()
    }

    static func main() throws -> Void {
        let plan = Self()

        if ProcessInfo.processInfo.arguments.contains("-h") || ProcessInfo.processInfo.arguments.contains("--help") {
            print(BuildCommand.helpMessage(), to: &StandardError)
            exit(0)
        }

        if ProcessInfo.processInfo.arguments.contains("--list-targets") {
            plan.listTargets()
            exit(0)
        }

        try plan.project.compile(for: plan.platform.supportedTargets, forceConfigure: plan.forceConfigure)
        if plan.platform.supportedTargets.contains(where: { $0.isApple }) {
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

    var targets: [Target] {
        do {
            let command = try BuildCommand.parse()
            var invalid: Target?
            for target in command.targets {
                let sameSDK = platform.supportedTargets.filter({ $0.systemName == target.systemName })
                guard !sameSDK.isEmpty else {
                    invalid = target
                    break
                }
                for arch in target.architectures {
                    guard sameSDK.contains(where: { $0.architectures.contains(arch) }) else {
                        invalid = target
                        break
                    }
                }
            }
            guard invalid == nil else {
                print("Unsupported platform: '\(invalid!.systemName.rawValue)-\(invalid!.architectures.map({ $0.rawValue }).joined(separator: "-"))'.", to: &StandardError)
                print("Pass '--show-targets' for a list of supported targets.", to: &StandardError)
                exit(1)
            }

            return command.targets
        } catch {
            return platform.supportedTargets
        }
    }
}