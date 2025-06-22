import Foundation

/// Represents the content of a build directory.
public struct Build {

    /// An error ocurred while merging binaries.
    public struct MergeError: Swift.Error {

        /// Program that failed.
        public var programName: String

        /// Exit code of the process.
        public var exitCode: Int
    }

    /// Targets present in the build directory.
    public var targets: [Target] {
        Array<Target>(buildDirs.keys)
    }

    internal var buildDirs: [Target:URL]

    /// Root build directory.
    public var buildRootDirectory: URL

    /// Directory containing universal Xcode frameworks created from declared dynamic libraries.
    public var appleUniversalBuildDirectoryURL: URL?

    private var products: [Product]

    private var versionString: String? {
        let projectName = buildRootDirectory.deletingLastPathComponent().lastPathComponent
        return ProjectNames[projectName]?.versionString
    }

    internal init(buildRootDirectory: URL, appleUniversalBuildDirectoryURL: URL?, buildDirs: [Target:URL], products: [Product]) {
        self.buildRootDirectory = buildRootDirectory
        self.appleUniversalBuildDirectoryURL = appleUniversalBuildDirectoryURL
        self.buildDirs = buildDirs
        self.products = products
    }

    /// Build directory for given target.
    /// 
    /// - Parameters:
    ///     - target: Target SDK and architecture of the products.
    ///
    /// - Returns: URL of the build directory.
    public func buildDirectoryURL(for target: Target) -> URL? {
        buildDirs[target]
    }

    private func target(from buildURL: URL) -> Target? {
        var build = false
        for component in buildURL.pathComponents {
            let parts = component.components(separatedBy: ".")
            if build, parts.count == 2, let systemName = Target.SystemName(rawValue: parts[0]) {
                var archs = [Target.Architecture]()
                for arch in parts[1].components(separatedBy: "-") {
                    guard let architecture = Target.Architecture(rawValue: arch) else {
                        continue
                    }
                    archs.append(architecture)
                }
                return Target(systemName: systemName, architectures: archs)
            }

            if component == "build" {
                build = true
            } else {
                build = false
            }
        }

        return nil
    }

    private func merge(urls: inout [URL]) throws {
        var newURLs = [URL]()

        var targets = [Target]()

        var filesToMerge = [Target.SystemName:[URL]]()
        for url in urls {
            guard let target = target(from: url) else {
                continue
            }
            if var mergedTarget = targets.first(where: { $0.systemName == target.systemName }) {
                for arch in target.architectures {
                    if !mergedTarget.architectures.contains(arch) {
                        mergedTarget.architectures.append(arch)
                    }
                }
                targets.removeAll(where: { $0.systemName == target.systemName })
            }
            if filesToMerge[target.systemName] == nil {
                filesToMerge[target.systemName] = []
            }
            filesToMerge[target.systemName]?.append(url)
        }

        for (systemName, urls) in filesToMerge {
            if urls.count == 1 {
                newURLs.append(urls[0])
            } else if urls.count > 1 {
                let buildDir = buildRootDirectory.appendingPathComponent("\(systemName.rawValue)-universal")
                var output = buildDir.appendingPathComponent(urls[0].lastPathComponent)
                if output.pathExtension == "framework" {
                    if systemName == .maccatalyst {
                        let fworkName = output.deletingPathExtension().lastPathComponent
                        output.appendPathComponent("Versions/Current")
                        output.appendPathComponent(fworkName)
                    } else {
                        output.appendPathComponent(output.deletingPathExtension().lastPathComponent)
                    }
                }

                try? FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: output.deletingLastPathComponent().path) {
                    try? FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
                }

                let lipo = Process()
                lipo.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
                lipo.arguments = [
                    "-create",
                    "-output", output.path
                ]
                var baseFramework: URL?
                for url in urls {
                    if url.pathExtension == "framework" {
                        lipo.arguments?.append(url.appendingPathComponent(url.deletingPathExtension().lastPathComponent).path)
                        baseFramework = url
                    } else {
                        lipo.arguments?.append(url.path)
                    }
                }

                if let baseFramework {
                    let universalFrameworkURL: URL
                    if systemName == .maccatalyst {
                        universalFrameworkURL = output.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                    } else {
                        universalFrameworkURL = output.deletingLastPathComponent()
                    }
                    if FileManager.default.fileExists(atPath: universalFrameworkURL.path) {
                        try FileManager.default.removeItem(at: universalFrameworkURL)
                    }
                    try FileManager.default.copyItem(at: baseFramework, to: universalFrameworkURL)
                }

                lipo.launch()
                lipo.waitUntilExit()

                if lipo.terminationStatus != 0 {
                    throw MergeError(programName: "lipo", exitCode: Int(lipo.terminationStatus))
                }

                if output.deletingLastPathComponent().pathExtension == "framework" {
                    output.deleteLastPathComponent()
                } else if systemName == .maccatalyst {
                    for _ in 0..<3 {
                        output.deleteLastPathComponent()
                    }
                }
                newURLs.append(output)
            }
        }

        urls = newURLs
    }

    /// Creates an Apple only Swift Package archive from Xcode Frameworks included as `binaryTarget`s.
    /// 
    /// - Parameters:
    ///     - xcodeFrameworks: URLs of Xcode frameworks to include.
    /// 
    /// - Returns: URL of the generated archive.
    public func createSwiftPackage(xcodeFrameworks: [URL]) throws -> URL? {

        guard let appleUniversalBuildDirectoryURL else {
            return nil
        }

        let packageName: String
        let shortPackageName: String
        if xcodeFrameworks.count == 1 {
            shortPackageName = xcodeFrameworks[0].deletingPathExtension().lastPathComponent
            packageName = "apple-"+shortPackageName
        } else {
            shortPackageName = Framework.frameworkify(buildRootDirectory.deletingLastPathComponent())
            packageName = "apple-"+shortPackageName
        }

        let targets = xcodeFrameworks.map({ $0.deletingPathExtension().lastPathComponent })
        var binaryTargets = ""
        for target in targets {
            binaryTargets += """
                    .binaryTarget(
                        name: "\(target)",
                        path: "\(target).xcframework"),\n
            """
        }

        let packageManifest = """
        // swift-tools-version:5.7
        import PackageDescription

        let package = Package(
            name: "\(packageName)",
            products: [
                .library(
                    name: "\(shortPackageName)",
                    targets: [
                        \(targets.map({ "\"\($0)\"" }).joined(separator: ", "))
                    ]
                )
            ],
            dependencies: [],
            targets: [
        \(binaryTargets)
            ]
        )
        """

        let packageDir = appleUniversalBuildDirectoryURL.appendingPathComponent(packageName)
        let packageManifestURL = packageDir.appendingPathComponent("Package.swift")
        let localPackageManifestURL = appleUniversalBuildDirectoryURL.appendingPathComponent("Package.swift")
        
        if FileManager.default.fileExists(atPath: packageDir.path) {
            try FileManager.default.removeItem(at: packageDir)
        }

        try FileManager.default.createDirectory(at: packageDir, withIntermediateDirectories: true)
        try packageManifest.write(to: packageManifestURL, atomically: true, encoding: .utf8)
        try packageManifest.write(to: localPackageManifestURL, atomically: true, encoding: .utf8)
        
        for framework in xcodeFrameworks {
            try FileManager.default.copyItem(at: framework, to: packageDir.appendingPathComponent(framework.lastPathComponent))
        }

        let archiveSource = Process()
        archiveSource.currentDirectoryURL = packageDir.resolvingSymlinksInPath()
        archiveSource.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        archiveSource.arguments = ["package", "archive-source"]
        archiveSource.launch()
        archiveSource.waitUntilExit()

        if archiveSource.terminationStatus != 0 {
            throw MergeError(programName: "swift", exitCode: Int(archiveSource.terminationStatus))
        }

        let archiveURL = appleUniversalBuildDirectoryURL.appendingPathComponent("\(packageName).zip")
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try FileManager.default.removeItem(at: archiveURL)
        }
        try FileManager.default.moveItem(at: packageDir.appendingPathComponent("\(packageName).zip"), to: archiveURL)
        try FileManager.default.removeItem(at: packageDir)

        // keep a symlink for local use
        try FileManager.default.createSymbolicLink(atPath: packageDir.path, withDestinationPath: ".")
        
        return archiveURL
    }

    /// Creates a Xcode frameworks with all of the compiled platforms and a zipped Swift package.
    /// Fails if no product is found targetting an Apple SDK.
    /// 
    /// - Parameters:
    ///     - bundleIdentifierPrefix: Bundle identifier prefix of the produced frameworks.
    /// 
    /// - Returns an URL of Xcode frameworks.
    public func createXcodeFrameworks(bundleIdentifierPrefix: String) throws -> [URL] {
        var targetsToMerge = [Target]()
        for (target, _) in buildDirs {
            if target.isApple {
                targetsToMerge.append(target)
            }
        }

        guard !targetsToMerge.isEmpty else {
            fputs("multibuild: Did not find Apple products platforms to create an Xcode Framework.", stderr)
            return []
        }

        let universalBuildDir = buildRootDirectory.appendingPathComponent("apple.universal")
        try? FileManager.default.createDirectory(at: universalBuildDir, withIntermediateDirectories: true)

        var dynamicLibraries = [Product]()
        var frameworks = [Product]()
        
        var staticArchiveFrameworks = [String:[URL]]()
        var staticArchivesLinkerFlags = [String:[((Target) -> [String])?]]()
        var staticArchivesToMergeIntoOneDylib = [String:[Product]]()
        var staticArchives = [Product]()
        
        for product in products {
            switch product.kind {
                case .dynamicLibrary:
                    dynamicLibraries.append(product)
                case .staticArchive(let merge, let linkerFlags):
                    if merge {
                        let defaultBinaryName = buildRootDirectory.deletingLastPathComponent().lastPathComponent
                        let binaryName = product.binaryName ?? defaultBinaryName

                        if staticArchivesToMergeIntoOneDylib[binaryName] != nil {
                            staticArchivesToMergeIntoOneDylib[binaryName]?.append(product)
                        } else {
                            staticArchivesToMergeIntoOneDylib[binaryName] = [product]
                        }

                        if staticArchivesLinkerFlags[binaryName] != nil {
                            staticArchivesLinkerFlags[binaryName]?.append(linkerFlags)
                        } else {
                            staticArchivesLinkerFlags[binaryName] = [linkerFlags]
                        }
                    } else {
                        staticArchives.append(product)
                    }
                case .framework:
                    frameworks.append(product)
            }
        }
        
        // -- Create frameworks from dylibs --
        
        var dylibFrameworks = [Target:[URL]]()
        for dylib in dynamicLibraries {
            guard let libPath = dylib.libraryPaths.first else {
                continue
            }
            for (target, directory) in buildDirs {
                
                if !dylibFrameworks.contains(where: { $0.key == target }) {
                    dylibFrameworks[target] = []
                }
                
                let dylibURL = directory.appendingPathComponent(libPath).resolvingSymlinksInPath()
                let includeURL = dylib.includePath == nil ? nil : directory.appendingPathComponent(dylib.includePath!)

                let framework = Framework(binaryURL: dylibURL, version: versionString ?? "1.0", installName: dylib.installName, includeURLs: includeURL == nil ? [] : [includeURL!], resourcesURLs: dylib.resources.map({ directory.appendingPathComponent($0) }), bundleIdentifierPrefix: bundleIdentifierPrefix)
                dylibFrameworks[target]?.append(try framework.write(to: directory))
            }
        }
        
        // -- Create dylibs from static archives and object files --

        if staticArchivesToMergeIntoOneDylib.count > 0 {
            for (target, directory) in buildDirs {
                for (binaryName, staticArchives) in staticArchivesToMergeIntoOneDylib {
                    let libraryMainURL = directory.appendingPathComponent("_library_main.c")
                    try "int _library_main() { return 0; }".write(to: libraryMainURL, atomically: false, encoding: .utf8)

                    var additionalLinkerFlags = [String]()
                    for flags in staticArchivesLinkerFlags[binaryName] ?? [] {
                        for flag in flags?(target) ?? [] {
                            additionalLinkerFlags.append(flag)
                        }
                    }
                    
                    var installName: String?
                    for archive in staticArchives {
                        if archive.installName != nil {
                            installName = archive.installName
                            break
                        }
                    }
                    
                    let process = Process()
                    process.currentDirectoryURL = buildDirectoryURL(for: target)?.resolvingSymlinksInPath()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                    process.arguments = [
                        "-sdk",
                        target.systemName == .maccatalyst ? "macosx" : target.systemName.rawValue,
                        "clang",
                        "-dynamiclib",
                        "-framework", "CoreFoundation",
                        "-framework", "Security",
                        "-lc++",
                        "-F.",
                        "-L."
                    ]+additionalLinkerFlags+(target.systemName == .maccatalyst ? [
                        "-target",
                        "\(target.architectures.map({ $0.rawValue }).joined(separator: "-"))-apple-ios13.1-macabi"
                    ] : [])
                    for arch in target.architectures {
                        process.arguments!.append(contentsOf: ["-arch", arch.rawValue])
                    }

                    var includeURLs = [URL]()
                    var headersURLs = [URL]()
                    var resourcesURLs = [URL]()
                    for staticArchive in staticArchives {
                        for libPath in staticArchive.libraryPaths {
                            let path = directory.appendingPathComponent(libPath).resolvingSymlinksInPath().path
                            if libPath.lowercased().hasSuffix(".a") {
                                process.arguments!.append(contentsOf: [
                                    "-force_load",
                                    path
                                ])
                            } else {
                                process.arguments!.append(path)
                            }
                        }
                        for resource in staticArchive.resources {
                            resourcesURLs.append(directory.appendingPathComponent(resource))
                        }
                        if let includePath = staticArchive.includePath {
                            let includeURL = directory.appendingPathComponent(includePath)
                            if !includeURLs.contains(includeURL) {
                                includeURLs.append(includeURL)
                            }
                        }
                        if let headers = staticArchive.headers {
                            for header in headers {
                                let headerURL = directory.appendingPathComponent(header)
                                if !headersURLs.contains(headerURL) {
                                    headersURLs.append(headerURL)
                                }
                            }
                        }
                    }

                    process.arguments!.append(contentsOf: [
                            libraryMainURL.path
                        ]+((target.isApple || installName != nil) ? ["-install_name", installName ?? "@rpath/\(binaryName).framework/\(binaryName)"] : [])+[
                            "-o", directory.appendingPathComponent(binaryName).path
                        ])
                    process.launch()
                    process.waitUntilExit()

                    if process.terminationStatus != 0 {
                        throw MergeError(programName: "clang", exitCode: Int(process.terminationStatus))
                    }

                    try FileManager.default.removeItem(at: libraryMainURL)

                    let framework = Framework(binaryURL: directory.appendingPathComponent(binaryName), version: versionString ?? "1.0", installName: installName, includeURLs: includeURLs, headersURLs: headersURLs, resourcesURLs: resourcesURLs, bundleIdentifierPrefix: bundleIdentifierPrefix)
                    if staticArchiveFrameworks[binaryName] == nil {
                        staticArchiveFrameworks[binaryName] = [try framework.write(to: directory)]
                    } else {
                        staticArchiveFrameworks[binaryName]?.append(try framework.write(to: directory))
                    }
                    try FileManager.default.removeItem(at: directory.appendingPathComponent(binaryName))
                }
            }
        }

        // -- Create Xcode frameworks --
        
        var xcframeworks = [URL]()
        if dylibFrameworks.count > 0 {
            var allFrameworks = [String:[URL]]() // group frameworks by name
            for (_, frameworks) in dylibFrameworks {
                guard frameworks.count > 0 else {
                    continue
                }
                
                for framework in frameworks {
                    if !allFrameworks.contains(where: { $0.key == framework.lastPathComponent }) {
                        allFrameworks[framework.lastPathComponent] = []
                    }
                    
                    allFrameworks[framework.lastPathComponent]?.append(framework)
                }
            }
            
            for (_, frameworks) in allFrameworks {
                
                var dylibFrameworks = frameworks
                
                try merge(urls: &dylibFrameworks)
                let xcodebuild = Process()
                xcodebuild.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
                xcodebuild.arguments = [
                    "-create-xcframework"
                ]
                for framework in dylibFrameworks {
                    xcodebuild.arguments!.append(contentsOf: [
                        "-framework", framework.path
                    ])
                }
                let xcframework = universalBuildDir.appendingPathComponent(dylibFrameworks[0].deletingPathExtension().lastPathComponent).appendingPathExtension("xcframework")
                if FileManager.default.fileExists(atPath: xcframework.path) {
                    try FileManager.default.removeItem(at: xcframework)
                }
                xcframeworks.append(xcframework)
                xcodebuild.arguments!.append(contentsOf: ["-output", xcframework.path])
                xcodebuild.launch()
                xcodebuild.waitUntilExit()

                if xcodebuild.terminationStatus != 0 {
                    throw MergeError(programName: "xcodebuild", exitCode: Int(xcodebuild.terminationStatus))
                }
            }
        }

        for (_, _frameworks) in staticArchiveFrameworks {
            var frameworks = _frameworks
            try merge(urls: &frameworks)
            let xcodebuild = Process()
            xcodebuild.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            xcodebuild.arguments = [
                "-create-xcframework"
            ]
            for framework in frameworks {
                xcodebuild.arguments!.append(contentsOf: [
                    "-framework", framework.path
                ])
            }
            let xcframework = universalBuildDir.appendingPathComponent(frameworks[0].deletingPathExtension().lastPathComponent).appendingPathExtension("xcframework")
            if FileManager.default.fileExists(atPath: xcframework.path) {
                try FileManager.default.removeItem(at: xcframework)
            }
            xcframeworks.append(xcframework)
            xcodebuild.arguments!.append(contentsOf: ["-output", xcframework.path])
            xcodebuild.launch()
            xcodebuild.waitUntilExit()

            if xcodebuild.terminationStatus != 0 {
                throw MergeError(programName: "xcodebuild", exitCode: Int(xcodebuild.terminationStatus))
            }
        }
        
        for framework in frameworks {
            guard let fworkPath = framework.libraryPaths.first else {
                continue
            }
            
            var frameworksArgs = [String]()
            var frameworks = [URL]()

            for (_, directory) in buildDirs {
                frameworks.append(directory.appendingPathComponent(fworkPath))
            }
            try merge(urls: &frameworks)

            for framework in frameworks {
                frameworksArgs.append(contentsOf: [
                    "-framework", framework.path
                ])
            }

            let xcframework = universalBuildDir.appendingPathComponent(fworkPath.components(separatedBy: "/").last ?? "").deletingPathExtension().appendingPathExtension("xcframework")
            if FileManager.default.fileExists(atPath: xcframework.path) {
                try FileManager.default.removeItem(at: xcframework)
            }
            xcframeworks.append(xcframework)
            let xcodebuild = Process()
            xcodebuild.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            xcodebuild.arguments = ["-create-xcframework"]+frameworksArgs+["-output", xcframework.path]
            xcodebuild.launch()
            xcodebuild.waitUntilExit()

            if xcodebuild.terminationStatus != 0 {
                throw MergeError(programName: "xcodebuild", exitCode: Int(xcodebuild.terminationStatus))
            }
        }

        for staticArchive in staticArchives {
            guard let libPath = staticArchive.libraryPaths.first else {
                continue
            }
            
            var librariesArgs = [String]()
            var libraries = [URL]()

            for (_, directory) in buildDirs {
                libraries.append(directory.appendingPathComponent(libPath))
            }
            try merge(urls: &libraries)

            for lib in libraries {
                librariesArgs.append(contentsOf: [
                    "-library", lib.path
                ])
                if let includePath = staticArchive.includePath {
                    librariesArgs.append(contentsOf: [
                        "-headers", includePath
                    ])
                }
            }

            let xcframework = universalBuildDir.appendingPathComponent(libPath.components(separatedBy: "/").last ?? "").deletingPathExtension().appendingPathExtension("xcframework")
            if FileManager.default.fileExists(atPath: xcframework.path) {
                try FileManager.default.removeItem(at: xcframework)
            }
            xcframeworks.append(xcframework)
            let xcodebuild = Process()
            xcodebuild.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            xcodebuild.arguments = ["-create-xcframework"]+librariesArgs+["-output", xcframework.path]
            xcodebuild.launch()
            xcodebuild.waitUntilExit()

            if xcodebuild.terminationStatus != 0 {
                throw MergeError(programName: "xcodebuild", exitCode: Int(xcodebuild.terminationStatus))
            }
        }

        return xcframeworks
    }
}
