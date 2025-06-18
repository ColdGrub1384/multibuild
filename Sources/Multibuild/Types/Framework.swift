import Foundation

/// An Apple only dynamic library bundle.
/// This structure is used for creating them.
public struct Framework {

    /// URL of the binary.
    public var binaryURL: URL

    /// Overriden  install name of the dynamic library.
    public var installName: String?
    
    /// URLs of include directories. Will be merged.
    public var includeURLs: [URL]

    /// URLs of header files.
    public var headersURLs: [URL]

    /// URL of resources to embed.
    public var resourcesURLs: [URL]
    
    /// Bundle Identifier prefix.
    public var bundleIdentifierPrefix: String

    internal var sdkName: Target.SystemName?

    internal var platformString: String?

    internal var minimumOSVersion: String?

    /// Initializes a framework instance.
    /// 
    /// - Parameters:
    ///   - binaryURL: URL of the binary.
    ///   - installName: Overriden  install name of a dynamic library.
    ///   - includeURLs: URLs of the include directory. Will be merged.
    ///   - headersURLs: URLs of header files.
    ///   - resourcesURLs: URLs  of resources to embed.
    ///   - bundleIdentifierPrefix: Bundle Identifier prefix.
    public init(binaryURL: URL, installName: String? = nil, includeURLs: [URL] = [], headersURLs: [URL] = [], resourcesURLs: [URL] = [], bundleIdentifierPrefix: String) {
        self.binaryURL = binaryURL
        self.installName = installName
        self.includeURLs = includeURLs
        self.headersURLs = headersURLs
        self.resourcesURLs = resourcesURLs
        self.bundleIdentifierPrefix = bundleIdentifierPrefix
        
        self.sdkName = getPlatform()
        switch sdkName {
            case .iphoneos:
                minimumOSVersion = "13.0"
                platformString = "iPhoneOS"
            case .iphonesimulator:
                minimumOSVersion = "13.0"
                platformString = "iPhoneSimulator"
            case .watchos:
                minimumOSVersion = "6.0"
                platformString = "WatchOS"
            case .watchsimulator:
                minimumOSVersion = "6.0"
                platformString = "WatchSimulator"
            case .maccatalyst:
                minimumOSVersion = "11.0"
                platformString = "MacOSX"
            default:
                break
        }
    }

    internal func getPlatform() -> Target.SystemName? {
        let output = Pipe()

        let otool = Process()
        otool.executableURL = URL(fileURLWithPath: "/usr/bin/otool")
        otool.arguments = ["-l", binaryURL.path]
        otool.standardOutput = output
        otool.launch()
        otool.waitUntilExit()

        if otool.terminationStatus != 0 {
            return nil
        } else if let string = String(data: output.fileHandleForReading.availableData, encoding: .utf8) {
            for line in string.components(separatedBy: "\n") {
                if line.hasPrefix(" platform ") {
                    let platform = line.components(separatedBy: " platform ").last ?? ""
                    switch Int(platform) ?? 0 {
                        case 2:
                            return .iphoneos
                        case 3:
                            return .appletvos
                        case 4:
                            return .watchos
                        case 6:
                            return .maccatalyst
                        case 7:
                            return .iphonesimulator
                        case 8:
                            return .appletvsimulator
                        case 9:
                            return .watchsimulator
                        default:
                            break
                    }
                }
            }
        }

        return nil
    }

    private func rewriteInstallName(binaryURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/install_name_tool")
        process.arguments = [
            "-id", installName ?? "@rpath/\(binaryURL.lastPathComponent).framework/\(binaryURL.lastPathComponent)",
            binaryURL.path
        ]
        process.launch()
        process.waitUntilExit()
    }

    private func copyHeaders(at url: URL, to dest: URL) throws {
        for file in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDir) else {
                continue
            }
            if file.pathExtension == "h" || file.pathExtension == "hpp" || file.pathExtension == "hh" {
                let destFile = dest.appendingPathComponent(file.lastPathComponent)
                if !FileManager.default.fileExists(atPath: destFile.path) {
                    try FileManager.default.copyItem(at: file, to: destFile)
                }
            } else if isDir.boolValue {
                let newDestURL = dest.appendingPathComponent(file.lastPathComponent)
                if !FileManager.default.fileExists(atPath: newDestURL.path) {
                    try FileManager.default.createDirectory(at: newDestURL, withIntermediateDirectories: true)
                }
                try copyHeaders(at: file, to: newDestURL)
            }
        }
    }

    internal  static func frameworkify(_ url: URL) -> String {
        var binaryName = url.deletingPathExtension().lastPathComponent
        if binaryName.hasPrefix("lib") {
            binaryName = String(binaryName.dropFirst(3))
        }
        binaryName = binaryName.components(separatedBy: ".").first ?? binaryName
        return binaryName
    }

    /// Creates the framework in a given location.
    /// 
    /// - Parameters:
    ///     - url: URL of the directory or the absolute framework URL.
    /// 
    /// - Returns: The URL of the framework.
    public func write(to url: URL) throws -> URL {
        if url.resolvingSymlinksInPath() != url {
            return try write(to: url.resolvingSymlinksInPath())
        }

        guard let infoPlist = Bundle.module.url(forResource: "Environment/Info", withExtension: "plist") else {
            print("Environment/Info.plist not found!", to: &StandardError)
            exit(1)
        }

        let plainName = binaryURL.lastPathComponent
                                    .replacingOccurrences(of: "-", with: "")
                                    .replacingOccurrences(of: " ", with: "")
                                    .replacingOccurrences(of: ".", with: "")

        let binaryName = Self.frameworkify(binaryURL)

        var content = try String(contentsOf: infoPlist)
        content = content.replacingOccurrences(of: "%BUNDLE_ID%", with: "\(bundleIdentifierPrefix).\(plainName)")
        content = content.replacingOccurrences(of: "%NAME%", with: binaryName)
        content = content.replacingOccurrences(of: "%MINIMUM_OS_VERSION%", with: minimumOSVersion ?? "")
        content = content.replacingOccurrences(of: "%PLATFORM%", with: platformString ?? "")

        var frameworkURL = url
        if frameworkURL.pathExtension != "framework" {
            frameworkURL = frameworkURL.appendingPathComponent(binaryName).appendingPathExtension("framework")
        }
        if FileManager.default.fileExists(atPath: frameworkURL.path) {
            try FileManager.default.removeItem(at: frameworkURL)
        }
        try FileManager.default.createDirectory(at: frameworkURL, withIntermediateDirectories: true)

        if sdkName == .maccatalyst {
            let versionURL = frameworkURL.appendingPathComponent("Versions/A")
            let resourcesURL = versionURL.appendingPathComponent("Resources")
            try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

            for resource in resourcesURLs {
                try FileManager.default.copyItem(at: resource, to: resourcesURL.appendingPathComponent(resource.lastPathComponent))
            }
            
            try FileManager.default.copyItem(at: binaryURL, to: versionURL.appendingPathComponent(binaryName))
            rewriteInstallName(binaryURL: versionURL.appendingPathComponent(binaryName))
            try content.write(to: resourcesURL.appendingPathComponent("Info.plist"), atomically: false, encoding: .utf8)

            if includeURLs.count > 0 || self.headersURLs.count > 0 {
                let headersURL = versionURL.appendingPathComponent("Headers")
                try FileManager.default.createDirectory(at: headersURL, withIntermediateDirectories: true)
                for url in includeURLs {
                    try copyHeaders(at: url, to: headersURL)
                }
                for url in self.headersURLs {
                    try FileManager.default.copyItem(at: url, to: headersURL.appendingPathComponent(url.lastPathComponent))
                }
                try FileManager.default.createSymbolicLink(atPath: frameworkURL.appendingPathComponent("Headers").path, withDestinationPath: "Versions/A/Headers")
            }

            try FileManager.default.createSymbolicLink(atPath: frameworkURL.appendingPathComponent(binaryName).path, withDestinationPath: "Versions/A/\(binaryName)")
            try FileManager.default.createSymbolicLink(atPath: frameworkURL.appendingPathComponent("Resources").path, withDestinationPath: "Versions/A/Resources")
            try FileManager.default.createSymbolicLink(atPath: frameworkURL.appendingPathComponent("Versions/Current").path, withDestinationPath: "A")
        } else {
            for resource in resourcesURLs {
                try FileManager.default.copyItem(at: resource, to: frameworkURL.appendingPathComponent(resource.lastPathComponent))
            }
            try FileManager.default.copyItem(at: binaryURL, to: frameworkURL.appendingPathComponent(binaryName))
            rewriteInstallName(binaryURL: frameworkURL.appendingPathComponent(binaryName))
            try content.write(to: frameworkURL.appendingPathComponent("Info.plist"), atomically: false, encoding: .utf8)
            if includeURLs.count > 0 || self.headersURLs.count > 0 {
                let headersURL = frameworkURL.appendingPathComponent("Headers")
                try FileManager.default.createDirectory(at: headersURL, withIntermediateDirectories: true)
                for url in includeURLs {
                    try copyHeaders(at: url, to: headersURL)
                }
                for url in self.headersURLs {
                    try FileManager.default.copyItem(at: url, to: headersURL.appendingPathComponent(url.lastPathComponent))
                }
            }
        }

        return frameworkURL
    }
}
