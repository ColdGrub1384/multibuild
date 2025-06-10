import Foundation

/// Uploading content to a Package Registry.
/// Can be returned from ``BuildPlan/packageUpload(for:)``.
public struct PackageUpload {

    /// Kind of Package Registry.
    public enum Kind {

        /// Swift Package Registry.
        case swift

        /// A generic package registry for any type of file.
        case generic
    }

    /// An error ocurred while uploading a package.
    public struct Error: Swift.Error {

        /// The exit code of the process.
        public var exitCode: Int
        
        /// The archive being uploaded.
        public var archiveURL: URL
    }

    /// User credentials.
    public struct User {

        /// Username for authentication.
        public var name: String

        /// Full name. Used in the package metadata.
        public var fullName: String

        /// Authentication token.
        public var token: String

        /// Initializes a user.
        /// 
        /// - Parameters:
        ///   - name: Username.
        ///   - fullName: Full name. Used in the package metadata.
        ///   - token: Authentication token.
        public init(name: String, fullName: String, token: String) {
            self.name = name
            self.fullName = fullName
            self.token = token
        }
    }

    /// URL of the package registry.
    /// Path must contain scope if it is a Swift Package Registry.
    public var registryURL: URL

    /// Kind of Package Registry.
    public var kind: Kind

    /// Authentication credentials.
    public var user: User

    /// Initializes a package upload.
    /// 
    /// - Parameters:
    ///   - kind: Kind of Package Registry.
    ///   - scope: Scope in the package registry.
    ///   - registryURL: URL of the package registry. Path must contain scope if it is a Swift Package Registry.
    ///   - user: Authentication credentials.
    public init(kind: Kind, registryURL: URL, user: User) {
        self.kind = kind
        self.registryURL = registryURL
        self.user = user
    }

    /// Start uploading the given archive.
    ///
    /// - Parameters:
    ///     - archive: Archive to upload.
    public func start(with archive: PackageArchive) throws {
        print("Uploading \(archive.url.path)...")

        let curl = Process()
        curl.currentDirectoryURL = archive.url.deletingLastPathComponent().resolvingSymlinksInPath()
        curl.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        switch kind {
            case .swift:
                curl.arguments = [
                    "-X", "PUT", "--user", "\(user.name):\(user.token)",
                    "-H", "Accept: application/vnd.swift.registry.v1+json",
                    "-F", "source-archive=@\(archive.url.lastPathComponent)",
                    "-F", "metadata={\"author\":{\"@type\":\"Person\", \"name\": \"\(user.fullName)\"}}",
                    registryURL.appendingPathComponent("\(archive.url.deletingPathExtension().lastPathComponent)/\(archive.version ?? "0.0.0")").absoluteString
                ]
            case .generic:
                curl.arguments = [
                    "--user", "\(user.name):\(user.token)",
                    "--upload-file", archive.url.lastPathComponent,
                    registryURL.appendingPathComponent("\(archive.name)/\(archive.version ?? "0.0.0")/\(archive.url.lastPathComponent)").absoluteString
                ]
        }
        try curl.run()
        curl.waitUntilExit()
        if curl.terminationStatus != 0 {
            throw Error(exitCode: Int(curl.terminationStatus), archiveURL: archive.url)
        }
    }
}