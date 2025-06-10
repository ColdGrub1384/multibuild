import Foundation

/// Package archive to upload with ``PackageUpload``.
public struct PackageArchive {

    /// Kind of package.
    public enum Kind {

        /// A Swift Package.
        case swiftPackage

        /// An Xcode Framework.
        case xcodeFramework
    }

    /// URL of the archive.
    public var url: URL

    /// Name of the package.
    public var name: String

    /// Version of the package.
    public var version: String?

    /// Kind of package.
    public var kind: Kind

    /// Initializes a package archive.
    /// 
    /// - Parameters:
    ///   - url: URL of the archive.
    ///   - name: Name of the package.
    ///   - version: Version of the package.
    ///   - kind: Kind of package.
    public init(url: URL, name: String, version: String?, kind: Kind) {
        self.url = url
        self.name = name
        self.version = version
        self.kind = kind
    }
}