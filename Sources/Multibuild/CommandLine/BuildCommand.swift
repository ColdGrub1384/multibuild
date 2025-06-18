import ArgumentParser
import Foundation
import ZIPFoundation

/// Argument parser for a command line program.
/// Can be constructed from a BuildPlan type and be parsed programatically.
/// For building your program's entry point, see ``BuildPlan``.
/// 
/// ```
/// OVERVIEW: Command line interface for building your projects.
/// 
/// USAGE: build-libraries [--root <root>] [--list-targets] [--list-projects] [--no-compile] [--no-upload] [--no-package] [--force-configure] [--target <target> ...] [--project <project> ...]
/// 
/// OPTIONS:
///   --root <root>           Common root directory of projects. (defaults to working directory)
///   --list-targets          List supported compilation targets and exit.
///   --list-projects         List declared projects and exit.
///   --no-compile            Skip recompilation and only perform packaging operations.
///   --no-upload             Skip uploading generated packages.
///   --no-package            Skip generation of Xcode Frameworks and Swift Packages.
///   -f, --force-configure   Force regenerating Makefiles and other configurations.
///   -t, --target <target>   Specify a target to build
///   -p, --project <project> Specify a project to build
///   -h, --help              Show help information.
/// ```
public struct BuildCommand<BuildPlanType: BuildPlan>: ParsableCommand {

    public static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0]).lastPathComponent, abstract: "Command line interface for building your projects.")
    }

    /// Common root directory of project (defaults to working directory).
    @Option(name: [.customLong("root")], help: "Common root directory of projects. (defaults to working directory)")
    public var rootDirectory: String?

    /// List supported compilation targets.
    @Flag(name: [.customLong("list-targets")], help: "List supported compilation targets and exit.")
    public var listTargets = false

    /// List declared projects.
    @Flag(name: [.customLong("list-projects")], help: "List declared projects and exit.")
    public var listProjects = false

    /// Skip recompilation and only perform packaging operations.
    @Flag(name: [.customLong("no-compile")], help: "Skip recompilation and only perform packaging operations.")
    public var noCompile = false

    /// Skip uploading packages.
    @Flag(name: [.customLong("no-upload")], help: "Skip uploading generated packages.")
    public var noUpload = false

    /// Skip generation of Xcode Frameworks and Swift Packages.
    @Flag(name: [.customLong("no-package")], help: "Skip generation of Xcode Frameworks and Swift Packages.")
    public var noPackaging = false

    /// Force regenerating configuration files. 
    @Flag(name: [.short, .customLong("force-configure")], help: "Force regenerating Makefiles and other configurations.")
    public var forceConfigure = false

    /// Targets to compile to. If none is passed, will compile for all supported targets. 
    @Option(name: [.short, .customLong("target")], help: "Specify a target to build")
    public var targets: [Target] = []

    /// Projects to compile. If none is passed, will compile for all projects. 
    @Option(name: [.short, .customLong("project")], help: "Specify a project to build")
    public var projects: [String] = []

    public init() {}

    /// Prints a list of supported targets separated by newlines.
    /// Each sdk name will print once with all supported architectures.
    public func doListTargets() {
        let plan = BuildPlanType()
        var fusedTargets = [Target]()
        for target in plan.platform.supportedTargets {
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

    /// Prints a list of declared projects separated by newlines.
    public func doListProjects() {
        let plan = BuildPlanType()
        if let dirName = plan.project.directoryURL?.lastPathComponent {
            print(dirName)
        } else {
            for dep in plan.project.dependencies {
                print(dep.project?.directoryURL.lastPathComponent ?? "")
            }
        }
    }

    /// Validates the targets passed as arguments.
    /// 
    /// - Throws: ``ArgumentParser.ValidationError``
    public func validateTargets() throws {
        let plan = BuildPlanType()
        var invalid: Target?
        for target in targets {
            let sameSDK = plan.platform.supportedTargets.filter({ $0.systemName == target.systemName })
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
            let targetName = "\(invalid!.systemName.rawValue)-\(invalid!.architectures.map({ $0.rawValue }).joined(separator: "-"))"
            throw ValidationError("Target '\(targetName)' is not supported.\nPass '--list-targets' for a list of targets.")
        }
    }
    
    private func findSubprojects(_ project: Project) -> [Project] {
        var projs = [Project]()
        if project.directoryURL == nil {
            for proj in project.dependencies.compactMap({ $0.project }) {
                if project.directoryURL != nil {
                    projs.append(proj)
                } else {
                    projs.append(contentsOf: findSubprojects(proj))
                }
            }
        } else {
            projs = [project]
        }
        return projs
    }

    /// Validates the projects passed as arguments.
    ///
    /// - Returns: The list of projects from the arguments.
    /// - Throws: ``ArgumentParser.ValidationError``
    public func validateProjects() throws -> [Project] {
        let plan = BuildPlanType()
        let projects = findSubprojects(plan.project)
        let command = try BuildCommand.parse()
        var projectsToCompile = [Project]()
        for projectName in command.projects {
            guard let project = projects.first(where: { $0.directoryURL?.lastPathComponent == projectName }) else {
                throw ValidationError("Project '\(projectName)' is not declared.\nPass --list-projects for a list of projects.")
            }
            projectsToCompile.append(project)
        }
        return projectsToCompile
    }

    public mutating func run() throws {
        let plan = BuildPlanType()

        if listTargets || listProjects {
            if listTargets {
                doListTargets()
            }

            if listProjects {
                doListProjects()
            }
            return
        }

        let projects = try validateProjects()
        let targets = self.targets.isEmpty ? plan.platform.supportedTargets : self.targets

        if !noCompile {
            if projects.isEmpty {
                try plan.project.compile(for: targets, forceConfigure: forceConfigure)
            } else {
                for project in projects {
                    try project.compile(for: targets, forceConfigure: forceConfigure)
                }
            }
        }
        
        if !noPackaging {
            if plan.platform.supportedTargets.contains(where: { $0.isApple }) {
                for dep in plan.project.dependencies {
                    var proj = dep.project
                    if proj == nil, let name = dep.name {
                        proj = ProjectNames[name]
                    }
                    
                    if !projects.isEmpty {
                        guard projects.contains(where: { $0.directoryURL.lastPathComponent == proj?.directoryURL.lastPathComponent }) else {
                            continue
                        }
                    }
                    
                    if let frameworks = try proj?.build?.createXcodeFrameworks(bundleIdentifierPrefix: plan.bundleIdentifierPrefix) {
                        for framework in frameworks {
                            let archiveURL = framework.deletingLastPathComponent().appendingPathComponent("apple-universal-\(framework.lastPathComponent).zip")
                            try FileManager.default.zipItem(at: framework, to: archiveURL)
                            let archive = PackageArchive(url: archiveURL, name: proj?.directoryURL.lastPathComponent ?? framework.deletingPathExtension().lastPathComponent, version: proj?.versionString, kind: .xcodeFramework)
                            if let upload = plan.packageUpload(for: archive), !noUpload {
                                try upload.start(with: archive)
                            }
                            try FileManager.default.removeItem(at: archiveURL)
                        }
                        
                        if let archiveURL = try proj?.build?.createSwiftPackage(xcodeFrameworks: frameworks) {
                            print("Generated Swift Package at \(archiveURL.path)")
                            let archive = PackageArchive(url: archiveURL, name: archiveURL.deletingPathExtension().lastPathComponent, version: proj?.versionString, kind: .swiftPackage)
                            if let upload = plan.packageUpload(for: archive), !noUpload {
                                try upload.start(with: archive)
                            }
                        }
                    }
                }
            }
        }
    }
}
