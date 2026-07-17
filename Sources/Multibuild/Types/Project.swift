import Foundation

internal var ProjectNames = [String:Project]()

/// Structure representing any project to compile.
/// A project is identified in the command line by the name of its directory.
/// 
/// This type contains information about the version, the build backend, the dependencies and contains functions for triggering builds. Projects depending on other projects are included in the `PKG_CONFIG_LIBDIR` environment variable so they can be found by build backends using pkg-config.
///
/// See also ``Builder``.
public struct Project {

    /// Version of the project used for packaging.
    public enum Version {

        /// A git branch, tag or commit to checkout to. It can also be passed a numerical version string to use while packaging.
        /// If it refers to a branch or commit, the latest tag name will be used to initialize a ``PackageArchive``.
        /// If the project doesn't have tags, you should provide a custom version string and manually checkout.
        case git(String, String? = nil)

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

    /// Formatted numerical version.
    public var versionString: String? {
        switch version {
            case .custom(let version):
                return Self.format(version: version)
            case .git(_, let versionString):
                if versionString != nil {
                    return versionString
                }
                let outputPipe = Pipe()
                let process = Process()
                process.currentDirectoryURL = directoryURL.resolvingSymlinksInPath()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = ["describe", "--tags", "--abbrev=0"]
                process.standardOutput = outputPipe
                process.standardError = Pipe()
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

    public var pkgConfigNames: [String]?

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
    
    internal init(projects: [Project]) {
        self.dependencies = projects.map({ Dependency.project($0) })
        for project in projects {
            if let directoryURL = project.directoryURL {
                ProjectNames[directoryURL.lastPathComponent] = project
            }
        }
    }

    /// Initializes a project.
    /// 
    /// - Parameters:
    ///   - directoryURL: Root location of the project. 
    ///   - version: A Version specified for packaging and checking out if it is a git version.
    ///   - patchURL: The URL of a patch to apply before compiling. Will be undone after.
    ///   - dependencies: Dependencies to build before compiling.
    ///   - builder: Build system.
    public init(directoryURL: URL,
                version: Version? = nil,
                patchURL: URL? = nil,
                pkgConfigNames: [String]? = nil,
                dependencies: [Dependency] = [],
                builder: Builder) {
        self.directoryURL = directoryURL
        self.version = version
        self.patchURL = patchURL
        self.pkgConfigNames = pkgConfigNames
        self.dependencies = dependencies
        
        // List producable wheels
        if var pythonBuilder = builder as? Python {
            var projectName = directoryURL.lastPathComponent
            let projectDeclarationURL = directoryURL.appendingPathComponent("pyproject.toml")
            
            do {
                var foundProjectSection = false
                if let projectDeclaration = try? String(contentsOf: projectDeclarationURL, encoding: .utf8) {
                    
                    for line in projectDeclaration.components(separatedBy: "\n") {
                        if line.hasPrefix("[project]") {
                            foundProjectSection = true
                        } else if line.replacingOccurrences(of: " ", with: "").hasPrefix("name=") && foundProjectSection {
                            projectName = line.replacingOccurrences(of: " ", with: "").components(separatedBy: "name=").last ?? projectName
                            projectName = projectName.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                            break
                        }
                    }
                }
            }
            
            for target in Platform.all.supportedTargets {
                let wheelName = "\(projectName)-\(versionString ?? "unknown")-cp\(pythonBuilder.buildInterpreter.rawValue.replacingOccurrences(of: ".", with: ""))-cp\(pythonBuilder.buildInterpreter.rawValue.replacingOccurrences(of: ".", with: ""))-\(target.soabiPlatform.replacingOccurrences(of: "-", with: "_"))_\(target.architectures[0].rawValue).whl"
                pythonBuilder.products.append(.wheel(wheelName, targets: [target]))
            }
            self.builder = pythonBuilder
        } else {
            self.builder = builder
        }
        
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
    
    private static func gitRepo(directory: URL) -> URL? {
        guard directory.resolvingSymlinksInPath().path.hasPrefix(FileManager.default.urls(for: .userDirectory, in: .allDomainsMask)[0].resolvingSymlinksInPath().path) else {
            return nil
        }
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent(".git").path) {
            return directory
        } else {
            return gitRepo(directory: directory.deletingLastPathComponent())
        }
    }

    /// Represents the content of the build directory.
    public var build: Build? {
        guard directoryURL != nil else {
            return nil
        }

        var buildDirs = [Target:URL]()
        var appleUniversalBuildDirectoryURL: URL?
        var rootURL = directoryURL.appendingPathComponent("build")
        do {
            if builder.outputDirectoryPath(for: Target(systemName: .maccatalyst, architectures: [.arm64, .x86_64])).hasPrefix("build/") {
                for filePath in try FileManager.default.contentsOfDirectory(atPath: rootURL.resolvingSymlinksInPath().path) {

                    let file = rootURL.appendingPathComponent(filePath)
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
            } else {
                for target in Platform.all.supportedTargets {
                    let buildDir = directoryURL.resolvingSymlinksInPath().appendingPathComponent(builder.outputDirectoryPath(for: target))
                    rootURL = buildDir.deletingLastPathComponent()
                    
                    if FileManager.default.fileExists(atPath: buildDir.path) {
                        buildDirs[target] = buildDir
                    }
                    
                    if target.architectures.count > 1 {
                        for architecture in target.architectures {
                            let splitTarget = Target(systemName: target.systemName, architectures: [architecture])
                            let buildDir = directoryURL.appendingPathComponent(builder.outputDirectoryPath(for: splitTarget))
                            if FileManager.default.fileExists(atPath: buildDir.path) {
                                buildDirs[splitTarget] = buildDir
                            }
                        }
                    }
                }
            }
        } catch {
            return nil
        }
        return Build(buildRootDirectory: rootURL, appleUniversalBuildDirectoryURL: appleUniversalBuildDirectoryURL, buildDirs: buildDirs, products: builder.products)
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

    internal func build(for targets: [Target],
                        universalBuild: Bool,
                        forceConfigure: Bool,
                        skipBuild: Bool,
                        package: Bool,
                        bundleIdentifierPrefix: String,
                        upload: Bool,
                        packageUpload: ((PackageArchive) -> PackageUpload?)) throws {

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

        // Checkout and apply patch
        let gitRepo = Self.gitRepo(directory: directoryURL.resolvingSymlinksInPath())
        let isGitRepo = (gitRepo != nil)
        let gitCheckout: String
        if case .git(let version, _) = self.version {
            gitCheckout = "git fetch --tags && git checkout \(version)"
        } else {
            gitCheckout = ""
        }

        let checkoutScriptURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("\(UUID().uuidString).sh")
        try """
        \(gitCheckout)
        \(patchURL != nil ? "\(isGitRepo ? "git reset" : "true") && git apply \(isGitRepo ? "--index" : "") \"\(patchURL!.path.replacingOccurrences(of: "\"", with: "\\\""))\" && git commit -m 'Apply patch'" : "true")
        """.write(to: checkoutScriptURL, atomically: false, encoding: .utf8)

        let checkout = Process()
        checkout.currentDirectoryURL = gitRepo ?? directoryURL.resolvingSymlinksInPath()
        checkout.executableURL = URL(fileURLWithPath: "/bin/bash")
        checkout.arguments = [checkoutScriptURL.path]
        checkout.launch()
        checkout.waitUntilExit()

        try FileManager.default.removeItem(at: checkoutScriptURL)

        // Install Python package in build machine
        if let pythonBuilder = builder as? Python, !Self.installedPythonPackages.contains(directoryURL.resolvingSymlinksInPath()), false {
            let pip = Process()
            pip.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            pip.arguments = ["python\(pythonBuilder.buildInterpreter.rawValue)", "-m", "pip", "install", "."]
            pip.currentDirectoryURL = directoryURL.resolvingSymlinksInPath()
            pip.launch()
            pip.waitUntilExit()
            Self.installedPythonPackages.append(directoryURL.resolvingSymlinksInPath())
        }
        
        if !skipBuild {
            for target in _targets {

                if universalBuild && builder is Python {
                    print("Universal build is unsupported for Python extensions.", to: &StandardError)
                    throw CompileError(exitCode: 1, target: target)
                }
                
                // Dependencies
                
                try doWillBuild(target)
                
                for dep in dependencies {
                    var project = dep.project
                    if project == nil, let name = dep.name {
                        project = ProjectNames[name]
                        if project == nil {
                            throw Dependency.NotFoundError(dependencyName: name)
                        }
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
                        try project!.compile(for: [target], universalBuild: universalBuild, forceConfigure: forceConfigure)
                        if package {
                            _ = try project!.build?.createXcodeFrameworks(bundleIdentifierPrefix: bundleIdentifierPrefix)
                        }
                        try project!.generatePackageConfiguration(for: [target])
                    }
                }
                
                // pkg-config
                var pkgConfigPath = [String]()
                for dep in dependencies.compactMap({
                    if let name = $0.name {
                        return ProjectNames[name]
                    } else {
                        return $0.project
                    }
                }) {
                    if let buildDir = dep.build?.buildDirectoryURL(for: target) {
                        pkgConfigPath.append(buildDir.path)
                    }
                }

                guard directoryURL != nil else {
                    return
                }

                // Build
                let buildScriptURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("\(UUID().uuidString).sh")
                try """
                cd \"\(directoryURL.path.replacingOccurrences(of: "\"", with: "\\\""))\"
                \(builder.buildScript(for: target, forceConfigure: forceConfigure))
                """.write(to: buildScriptURL, atomically: false, encoding: .utf8)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.environment = [:]
                process.environment?["PKG_CONFIG_LIBDIR"] = pkgConfigPath.joined(separator: ":")
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
                    (builder as? Python)?.buildInterpreter.rawValue ?? "3.14"
                ]

                process.launch()
                process.waitUntilExit()

                try FileManager.default.removeItem(at: buildScriptURL)

                // Built
                if process.terminationStatus != 0 {
                    let error = CompileError(exitCode: Int(process.terminationStatus), target: target)
                    try doDidBuild(target, error)
                    throw error
                }

                try doDidBuild(target, nil)
            }
        }
        
        // Undo patch
        if let patch = patchURL?.path {
            let revertPatch = Process()
            revertPatch.currentDirectoryURL = gitRepo ?? directoryURL.resolvingSymlinksInPath()
            revertPatch.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            if isGitRepo {
                revertPatch.arguments = ["reset", "--hard", "HEAD~1"]
            } else {
                revertPatch.arguments = ["apply", "-R", patch]
            }
            revertPatch.launch()
            revertPatch.waitUntilExit()
        }


        // Package
        if targets.contains(where: { $0.isApple }) && package && !(builder is Python) {
            if let frameworks = try build?.createXcodeFrameworks(bundleIdentifierPrefix: bundleIdentifierPrefix) {
                for framework in frameworks {
                    let archiveURL = framework.deletingLastPathComponent().appendingPathComponent("apple-universal-\(framework.lastPathComponent).zip")
                    try? FileManager.default.removeItem(at: archiveURL)
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

            try generatePackageConfiguration(for: _targets)
        } else if let builder = builder as? Python {
            for target in _targets {
                guard let wheelURL = build?.wheelURL(for: target, python: builder.buildInterpreter) else {
                    continue
                }
                
                let archive = PackageArchive(url: wheelURL, name: wheelURL.lastPathComponent.components(separatedBy: "-")[0], version: wheelURL.lastPathComponent.components(separatedBy: "-")[1], kind: .pythonWheel)
                if let packageUpload = packageUpload(archive), upload {
                    try packageUpload.start(with: archive)
                }
            }
        }
    }

    /// Generates pkg-config files. Set ``Project/pkgConfigNames`` to customize the name(s), othewise it will be set to the project's directory name. This function is called after a build is complete if packaging is on.
    ///
    /// - Parameters:
    ///     - targets: Target platforms to process.
    public func generatePackageConfiguration(for targets: [Target]) throws {
        for target in targets {
            guard let buildDir = build?.buildDirectoryURL(for: target) else {
                continue
            }

            for file in try FileManager.default.contentsOfDirectory(at: buildDir, includingPropertiesForKeys: nil) {
                if file.pathExtension == "pc" {
                    try FileManager.default.removeItem(at: file)
                }
            }

            var includeFlags = [String]()
            var linkFlags = [String]()
            let version = versionString ?? "unknown"

            if FileManager.default.fileExists(atPath: buildDir.appendingPathComponent("include").path) {
                includeFlags.append("-I${prefix}/include")
            }

            // generate configurations from project name and also from frameworks name
            var configNames = [directoryURL.lastPathComponent]
            for lib in builder.products {
                let libName: String
                if let binaryName = lib.binaryName {
                    libName = Framework.frameworkify(buildDir.appendingPathComponent(binaryName))
                } else if case .staticArchive(mergeIntoDylib: let merge, additionalLinkerFlags: _) = lib.kind, merge, lib.binaryName == nil {
                    libName = Framework.frameworkify(buildDir.appendingPathComponent(directoryURL.lastPathComponent))
                } else if lib.libraryPaths.count == 1 {
                    libName = Framework.frameworkify(buildDir.appendingPathComponent(lib.libraryPaths[0]))
                } else {
                    libName = directoryURL.lastPathComponent
                }
                if !configNames.contains(libName) {
                    configNames.append(libName)
                }
                if !configNames.contains("lib\(libName)") {
                    configNames.append("lib\(libName)")
                }

                if let includePath = lib.includePath {
                    includeFlags.append("-I${prefix}/\(includePath)")
                }

                if target.isApple {
                    let frameworPath: String?
                    let staticLibName: String?
                    switch lib.kind {
                        case .dynamicLibrary, .framework:
                            frameworPath = "\(libName).framework"
                            staticLibName = nil
                        case .staticArchive(mergeIntoDylib: let merge, additionalLinkerFlags: _):
                            if merge {
                                frameworPath = "\(libName).framework"
                                staticLibName = nil
                            } else {
                                frameworPath = nil
                                staticLibName = libName
                            }
                        default:
                            frameworPath = nil
                            staticLibName = nil
                    }

                    if let frameworPath, FileManager.default.fileExists(atPath: buildDir.appendingPathComponent(frameworPath).path) {
                        if FileManager.default.fileExists(atPath: buildDir.appendingPathComponent(frameworPath).appendingPathComponent("Headers").path) {
                            includeFlags.append("-I${prefix}/\(frameworPath)/Headers")
                        }
                        linkFlags.append("-F${prefix}")
                        linkFlags.append("-framework")
                        linkFlags.append(Framework.frameworkify(buildDir.appendingPathComponent(frameworPath)))
                    } else if let staticLibName, FileManager.default.fileExists(atPath: buildDir.appendingPathComponent("lib\(staticLibName).a").path) {
                        linkFlags.append("-L${prefix}")
                        linkFlags.append("-l\(staticLibName)")
                    }
                } else {
                    let libPath: String?
                    switch lib.kind {
                        case .dynamicLibrary:
                            libPath = lib.libraryPaths.first
                        case .staticArchive(mergeIntoDylib: let merge, additionalLinkerFlags: _):
                            if merge {
                                libPath = libName+".so"
                            } else {
                                libPath = nil
                            }
                        default:
                            libPath = nil
                    }

                    if let libPath, FileManager.default.fileExists(atPath: buildDir.appendingPathComponent(libPath).path) {
                        linkFlags.append("-L${prefix}")
                        linkFlags.append("-l\(Framework.frameworkify(buildDir.appendingPathComponent(libPath)))")
                    }
                }
            }

            for name in pkgConfigNames ?? configNames {
                try """
                prefix=\(buildDir.path)

                Name: \(name)
                Description:
                Version: \(version)
                Cflags: \(includeFlags.joined(separator: " "))
                Libs: \(linkFlags.joined(separator: " "))
                """.write(to: buildDir.appendingPathComponent("\(name).pc"), atomically: true, encoding: .utf8)
            }
        }
    }
}
