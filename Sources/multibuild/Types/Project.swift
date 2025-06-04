import Foundation

/// Structure representing any project to compile.
public struct Project {

    /// Root location of the project. 
    public var directoryURL: URL

    /// A Git branch, tag or commit to checkout out before compiling.
    public var gitVersion: String?

    /// The URL of a patch to apply before compiling. Will be undone after.
    public var patchURL: URL?

    /// Backend build system.
    public var backend: BuildBackend

    /// Initializes a project.
    /// 
    /// - Parameters:
    ///   - directoryURL: Root location of the project. 
    ///   - gitVersion: A Git branch, tag or commit to checkout out before compiling.
    ///   - patchURL: The URL of a patch to apply before compiling. Will be undone after.
    ///   - backend: Backend build system.
    public init(directoryURL: URL, gitVersion: String? = nil, patchURL: URL? = nil, backend: BuildBackend) {
        self.directoryURL = directoryURL
        self.gitVersion = gitVersion
        self.patchURL = patchURL
        self.backend = backend
    }

    /// An error ocurred while compiling a target.
    public struct CompileError: Error {

        /// The exit code of the process.
        public var exitCode: Int
        
        /// The target that was being compiled to.
        public var target: Target
    }

    /// Represents the content of the build directory.
    public var build: Build {
        var buildDirs = [Target:URL]()
        for file in (try? FileManager.default.contentsOfDirectory(at: directoryURL.appendingPathComponent("build"), includingPropertiesForKeys: nil)) ?? [] {
            let comps = file.lastPathComponent.components(separatedBy: ".")
            guard comps.count == 2, let sdk = Target.SystemName(rawValue: comps[0]) else {
                continue
            }
            let archs = comps[1].components(separatedBy: "-").compactMap({ Target.Architecture(rawValue: $0) })
            buildDirs[Target(systemName: sdk, architectures: archs)] = file 
        }
        return Build(buildRootDirectory: directoryURL.appendingPathComponent("build"), buildDirs: buildDirs, products: backend.products)
    }

    /// Compiles the project for a given platform.
    ///
    /// - Parameters:
    ///     - platform: The platform being compiled to with all the supported targets.
    ///     - universalBuild: If set to ´true´, will target multiple architectures when they're the same SDK.
    public func compile(for platform: Platform, universalBuild: Bool = false) throws {
        try compile(for: platform.supportedTargets, universalBuild: universalBuild)
    }

    /// Compiles the project for a given target.
    ///
    /// - Parameters:
    ///     - target: The target being compiled to.
    ///     - universalBuild: If set to ´true´, will target multiple architectures when they're the same SDK.
    public func compile(for target: Target, universalBuild: Bool = false) throws {
        try compile(for: [target], universalBuild: universalBuild)
    }

    /// Compiles the project for a given list of targets.
    ///
    /// - Parameters:
    ///     - targets: List of targets being compiled to.
    ///     - universalBuild: If set to ´true´, will target multiple architectures when they're the same SDK.
    public func compile(for targets: [Target], universalBuild: Bool = false) throws {
        
        var _targets = [Target]()
        if universalBuild {
            _targets = targets
        } else { // On non universal builds, split targets per each architecture
            for target in targets {
                for arch in target.architectures {
                    _targets.append(Target(systemName: target.systemName, architectures: [arch]))
                }
            }
        }

        for target in _targets {
            let buildScriptURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("\(UUID().uuidString).sh")
            try """
            cd "\(directoryURL.path)"
            \(gitVersion != nil ? "git fetch --tags && git checkout \(gitVersion!)" : "")
            \(patchURL != nil ? "git apply \"\(patchURL!.path.replacingOccurrences(of: "\"", with: "\\\""))\"" : "")
            \(backend.buildScript(for: target))
            """.write(to: buildScriptURL, atomically: false, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.environment = backend.environment(for: target)
            process.environment?["BUILD_SCRIPT"] = buildScriptURL.path
            for (key, value) in ProcessInfo.processInfo.environment {
                process.environment?[key] = value
            }
            for (key, value) in backend.defaultEnvironment(for: target) {
                process.environment?[key] = value
            }
            process.arguments = [
                Bundle.module.url(forResource: "Environment/environment", withExtension: "sh")!.path,
                "3.14"
            ]

            process.launch()
            process.waitUntilExit()

            try FileManager.default.removeItem(at: buildScriptURL)

            if let patch = patchURL?.path {
                let revertPatch = Process()
                revertPatch.currentDirectoryURL = directoryURL
                revertPatch.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                revertPatch.arguments = ["apply", "-R", patch]
                revertPatch.launch()
                revertPatch.waitUntilExit()
            }

            if process.terminationStatus != 0 {
                throw CompileError(exitCode: Int(process.terminationStatus), target: target)
            }
        }
    }
}