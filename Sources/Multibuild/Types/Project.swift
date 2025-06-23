import Foundation

internal var ProjectNames = [String:Project]()
internal var BuiltProjects = [URL]()

/// Structure representing any project to compile.
public struct Project {

    /// Version of the project used for packaging.
    public enum Version {

        /// A git branch, tag or commit to checkout to.
        /// If it refers to a branch or commit, the latest tag name will be used to initialize a ``PackageArchive``.
        /// If the project doesn't have tags, you should provide a custom version string and manually checkout.
        case git(String)

        /// A custom version string.
        case custom(String)
    }

    internal static func format(version: String) -> String {
        var newVersion = ""
        for char in version {
            if char == "v" {
                continue
            } else if Set("0123456789.").contains(char) {
                newVersion.append(char)
            } else if !newVersion.isEmpty {
                break
            }
        }
        
        return newVersion
    }

    internal var versionString: String? {
        switch version {
            case .custom(let version):
                return Self.format(version: version)
            case .git(_):
                let outputPipe = Pipe()
                let process = Process()
                process.currentDirectoryURL = directoryURL.resolvingSymlinksInPath()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = ["describe", "--tags", "--abbrev=0"]
                process.standardOutput = outputPipe
                process.launch()
                process.waitUntilExit()

                let data = outputPipe.fileHandleForReading.availableData
                guard let versionString = String(data: data, encoding: .utf8) else {
                    return nil
                }

                return Self.format(version: versionString)
            default:
                return nil
        }
    }

    /// Root location of the project. 
    public var directoryURL: URL!

    /// A Version specified for packaging and checking out if it is a git version.
    public var version: Version?

    /// The URL of a patch to apply before compiling. Will be undone after.
    public var patchURL: URL?

    /// Build system.
    public var builder: Builder!

    private var _dependencies = [Dependency]()
    
    /// Dependencies to build before compiling.
    public var dependencies: [Dependency] {
        set {
            _dependencies = newValue
        }
        
        get {
            func find(deps: [Dependency]) -> [Dependency] {
                var _deps = [Dependency]()
                for dep in deps {
                    if let proj = dep.project {
                        if proj.directoryURL == nil {
                            _deps.append(contentsOf: find(deps: proj.dependencies))
                        } else {
                            _deps.append(dep)
                        }
                    } else {
                        _deps.append(dep)
                    }
                }
                return _deps
            }
            
            return find(deps: _dependencies)
        }
    }

    internal var willBuild = [((Target) throws -> Void)]()

    internal var didBuild = [(Target, Error?) throws -> Void]()

    internal func doWillBuild(_ target: Target) throws {
        for block in willBuild {
            try block(target)
        }
    }
    
    internal func doDidBuild(_ target: Target, _ error: Error?) throws {
        for block in didBuild {
            try block(target, error)
        }
    }
    
    internal var _build: Build?

    internal init(projects: [Project]) {
        self.dependencies = projects.map({ Dependency.project($0) })
    }

    /// Initializes a project.
    /// 
    /// - Parameters:
    ///   - directoryURL: Root location of the project. 
    ///   - version: A Version specified for packaging and checking out if it is a git version.
    ///   - patchURL: The URL of a patch to apply before compiling. Will be undone after.
    ///   - dependencies: Dependencies to build before compiling.
    ///   - builder: Build system.
    public init(directoryURL: URL, version: Version? = nil, patchURL: URL? = nil, dependencies: [Dependency] = [], builder: Builder) {
        self.directoryURL = directoryURL
        self.version = version
        self.patchURL = patchURL
        self.dependencies = dependencies
        self.builder = builder
        ProjectNames[directoryURL.lastPathComponent] = self
    }

    /// Set a block called before building.
    /// 
    /// - Parameters:
    ///     - block: Called before building. Takes the target being compiled to as parameter.
    /// 
    /// - Returns: A Project instance that calls `block` before compiling.
    public func willBuild(_ block: @escaping ((Target) throws -> Void)) -> Project {
        var proj = self
        proj.willBuild.append(block)
        ProjectNames[directoryURL.lastPathComponent] = proj
        return proj
    }

    /// Set a block called after building.
    /// 
    /// - Parameters:
    ///     - block: Called after building. Takes the target being compiled to and an optional error as parameters.
    /// 
    /// - Returns: A Project instance that calls `block` after compiling.
    public func didBuild(_ block: @escaping  ((Target, Error?) throws -> Void)) -> Project {
        var proj = self
        proj.didBuild.append(block)
        ProjectNames[directoryURL.lastPathComponent] = proj
        return proj
    }

    /// An error ocurred while compiling a target.
    public struct CompileError: Error {

        /// The exit code of the process.
        public var exitCode: Int
        
        /// The target that was being compiled to.
        public var target: Target
    }

    /// Represents the content of the build directory.
    public var build: Build? {
        if let _build {
            return _build
        }

        guard directoryURL != nil else {
            return nil
        }

        var buildDirs = [Target:URL]()
        var appleUniversalBuildDirectoryURL: URL?
        do {
            for file in try FileManager.default.contentsOfDirectory(at: directoryURL.appendingPathComponent("build"), includingPropertiesForKeys: nil) {
                if file.lastPathComponent == "apple.universal" {
                    appleUniversalBuildDirectoryURL = file
                    continue
                }
                let comps = file.lastPathComponent.components(separatedBy: ".")
                guard comps.count == 2, let sdk = Target.SystemName(rawValue: comps[0]) else {
                    continue
                }
                let archs = comps[1].components(separatedBy: "-").compactMap({ Target.Architecture(rawValue: $0) })
                buildDirs[Target(systemName: sdk, architectures: archs)] = file 
            }
        } catch {
            return nil
        }
        return Build(buildRootDirectory: directoryURL.appendingPathComponent("build"), appleUniversalBuildDirectoryURL: appleUniversalBuildDirectoryURL, buildDirs: buildDirs, products: builder.products)
    }

    /// Compiles the project for a given platform.
    ///
    /// - Parameters:
    ///     - platform: The platform being compiled to with all the supported targets.
    ///     - universalBuild: If set to ´true´, will target multiple architectures when they're the same SDK.
    ///     - forceConfigure: Force regenerating configuration files.
    public func compile(for platform: Platform, universalBuild: Bool = false, forceConfigure: Bool = false) throws {
        try compile(for: platform.supportedTargets, universalBuild: universalBuild, forceConfigure: forceConfigure)
    }

    /// Compiles the project for a given target.
    ///
    /// - Parameters:
    ///     - target: The target being compiled to.
    ///     - universalBuild: If set to ´true´, will target multiple architectures when they're the same SDK.
    ///     - forceConfigure: Force regenerating configuration files.
    public func compile(for target: Target, universalBuild: Bool = false, forceConfigure: Bool = false) throws {
        try compile(for: [target], universalBuild: universalBuild, forceConfigure: forceConfigure)
    }

    /// Compiles the project for a given list of targets.
    ///
    /// - Parameters:
    ///     - targets: List of targets being compiled to.
    ///     - universalBuild: If set to ´true´, will target multiple architectures when they're the same SDK.
    ///     - forceConfigure: Force regenerating configuration files.
    public func compile(for targets: [Target], universalBuild: Bool = false, forceConfigure: Bool = false) throws {
        try build(for: targets, 
                    universalBuild: universalBuild,
                    forceConfigure: forceConfigure,
                    skipBuild: false,
                    package: false,
                    bundleIdentifierPrefix: "",
                    upload: false,
                    packageUpload: { _ in
            nil
        })
    }

    internal func build(
        for targets: [Target],
        universalBuild: Bool,
        forceConfigure: Bool,
        skipBuild: Bool,
        package: Bool,
        bundleIdentifierPrefix: String,
        upload: Bool,
        packageUpload: ((PackageArchive) -> PackageUpload?)) throws {

        if !skipBuild {
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

            for dep in dependencies {
                var project = dep.project
                if project == nil, let name = dep.name {
                    project = ProjectNames[name]
                    if project == nil {
                        throw Dependency.NotFoundError(dependencyName: name)
                    }
                }

                guard !BuiltProjects.contains(project!.directoryURL) else {
                    continue
                }

                // Build only if products are not present
                var compile = forceConfigure
                if project!.builder.products.isEmpty {
                    compile = true
                }
                for product in project!.builder.products {
                    for path in product.libraryPaths {
                        for target in _targets {
                            guard let url = project!.build?.buildDirectoryURL(for: target)?.appendingPathComponent(path) else {
                                compile = true
                                break
                            }
                            if !FileManager.default.fileExists(atPath: url.path) {
                                compile = true
                                break
                            }
                        }
                    }
                }
                if compile {
                    try project!.compile(for: targets, universalBuild: universalBuild, forceConfigure: forceConfigure)
                }
            }

            guard directoryURL != nil else {
                return
            }

            for target in _targets {

                // Checkout and apply patch

                let gitCheckout: String
                if case .git(let version) = self.version {
                    gitCheckout = "git fetch --tags && git checkout \(version)"
                } else {
                    gitCheckout = ""
                }

                let checkoutScriptURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("\(UUID().uuidString).sh")
                try """
                \(gitCheckout)
                \(patchURL != nil ? "git apply \"\(patchURL!.path.replacingOccurrences(of: "\"", with: "\\\""))\"" : "")
                """.write(to: checkoutScriptURL, atomically: false, encoding: .utf8)

                let checkout = Process()
                checkout.currentDirectoryURL = directoryURL.resolvingSymlinksInPath()
                checkout.executableURL = URL(fileURLWithPath: "/bin/bash")
                checkout.arguments = [checkoutScriptURL.path]
                checkout.launch()
                checkout.waitUntilExit()

                try FileManager.default.removeItem(at: checkoutScriptURL)

                // Build

                try doWillBuild(target)

                let buildScriptURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("\(UUID().uuidString).sh")
                try """
                cd \"\(directoryURL.path.replacingOccurrences(of: "\"", with: "\\\""))\"
                \(builder.buildScript(for: target, forceConfigure: forceConfigure))
                """.write(to: buildScriptURL, atomically: false, encoding: .utf8)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.environment = [:]
                process.environment?["BUILD_SCRIPT"] = buildScriptURL.path
                for (key, value) in ProcessInfo.processInfo.environment {
                    process.environment?[key] = value
                }
                for (key, value) in builder.defaultEnvironment(for: target) {
                    process.environment?[key] = value
                }
                for (key, value) in builder.environment?(target) ?? [:] {
                    process.environment?[key] = value
                }
                process.arguments = [
                    Bundle.module.url(forResource: "Environment/environment", withExtension: "sh")!.path,
                    "3.14"
                ]

                process.launch()
                process.waitUntilExit()

                try FileManager.default.removeItem(at: buildScriptURL)

                // Undo patch

                if let patch = patchURL?.path {
                    let revertPatch = Process()
                    revertPatch.currentDirectoryURL = directoryURL.resolvingSymlinksInPath()
                    revertPatch.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                    revertPatch.arguments = ["apply", "-R", patch]
                    revertPatch.launch()
                    revertPatch.waitUntilExit()
                }

                // Built

                if process.terminationStatus != 0 {
                    let error = CompileError(exitCode: Int(process.terminationStatus), target: target)
                    try doDidBuild(target, error)
                    throw error
                }

                try doDidBuild(target, nil)
            }
        }

        BuiltProjects.append(directoryURL)

        // Package
        if targets.contains(where: { $0.isApple }) && package {
            if let frameworks = try build?.createXcodeFrameworks(bundleIdentifierPrefix: bundleIdentifierPrefix) {
                for framework in frameworks {
                    let archiveURL = framework.deletingLastPathComponent().appendingPathComponent("apple-universal-\(framework.lastPathComponent).zip")
                    try FileManager.default.zipItem(at: framework, to: archiveURL)
                    let archive = PackageArchive(url: archiveURL, name: directoryURL.lastPathComponent, version: versionString, kind: .xcodeFramework)
                    if let packageUpload = packageUpload(archive), upload {
                        try packageUpload.start(with: archive)
                    }
                    try FileManager.default.removeItem(at: archiveURL)
                }

                if let archiveURL = try build?.createSwiftPackage(xcodeFrameworks: frameworks) {
                    print("Generated Swift Package at \(archiveURL.path)")
                    let archive = PackageArchive(url: archiveURL, name: archiveURL.deletingPathExtension().lastPathComponent, version: versionString, kind: .swiftPackage)
                    if let packageUpload = packageUpload(archive), upload {
                        try packageUpload.start(with: archive)
                    }
                }
            }
        }
    }
}
