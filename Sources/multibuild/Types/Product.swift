import Foundation

/// Represents a product of the build abstracted from the target.
public struct Product {

    /// The kind of compiler output. 
    public enum Kind {
        /// Static archive.
        ///
        /// - Parameters:
        ///     - mergeIntoDylib: If set to to ´true´, will merge along all other decalred static archives into one dynamic libraries.
        ///     - additionalLinkerFlags: A list of flags passed to the linker.
        case staticArchive(mergeIntoDylib: Bool, additionalLinkerFlags: [String]?)

        /// A dynamic library. Which automatically produces frameworks for Apple platforms.
        case dynamicLibrary
    }


    /// Name of the hypothetical dynamic libraries created from static archives.
    public var binaryName: String?

    /// A path of binary libraries.
    public var libraryPaths: [String]

    /// The path of the directory containing the header files of the library.
    public var includePath: String?

    /// A list of header file paths.
    public var headers: [String]?

    /// Kind of binary.
    public var kind: Kind

    internal init(filePaths: [String], binaryName: String? = nil, includePath: String?, kind: Kind) {
        self.libraryPaths = filePaths
        self.binaryName = binaryName
        self.includePath = includePath
        self.kind = kind
    }

    internal init(filePaths: [String], binaryName: String? = nil, headers: [String]?, kind: Kind) {
        self.libraryPaths = filePaths
        self.binaryName = binaryName
        self.headers = headers
        self.kind = kind
    }


    /// A static archive.
    /// 
    /// - Parameters: 
    ///     - file: Path of the binary relative to the build directory.
    ///     - additionalLinkerFlags: Linker flags passed in case of merging libraries.
    public static func staticArchive(_ file: String, additionalLinkerFlags: [String]? = nil) -> Product {
        return Product(filePaths: [file], includePath: nil, kind: .staticArchive(mergeIntoDylib: false, additionalLinkerFlags: additionalLinkerFlags))
    }

    /// A static archive.
    /// 
    /// - Parameters: 
    ///     - file: Path of the binary relative to the build directory.
    ///     - includePath: Path of directory containing headers.
    ///     - additionalLinkerFlags: Linker flags passed in case of merging libraries.
    public static func staticArchive(_ file: String, includePath: String?, additionalLinkerFlags: [String]? = nil) -> Product {
        return Product(filePaths: [file], includePath: includePath, kind: .staticArchive(mergeIntoDylib: false, additionalLinkerFlags: additionalLinkerFlags))
    }

    /// A static archive.
    /// 
    /// - Parameters: 
    ///     - file: Path of the binary relative to the build directory.
    ///     - headers: List of header file paths.
    ///     - additionalLinkerFlags: Linker flags passed in case of merging libraries.
    public static func staticArchive(_ file: String, headers: [String]?, additionalLinkerFlags: [String]? = nil) -> Product {
        return Product(filePaths: [file], headers: headers, kind: .staticArchive(mergeIntoDylib: false, additionalLinkerFlags: additionalLinkerFlags))
    }


    /// A dynamic library.
    /// 
    /// - Parameters: 
    ///     - file: Path of the binary relative to the build directory.
    ///     - headers: List of header file paths.
    public static func dynamicLibrary(_ file: String) -> Product {
        return Product(filePaths: [file], includePath: nil, kind: .dynamicLibrary)
    }


    /// A dynamic library.
    /// 
    /// - Parameters: 
    ///     - file: Path of the binary relative to the build directory.
    ///     - includePath: List of header file paths.
    public static func dynamicLibrary(_ file: String, includePath: String?) -> Product {
        return Product(filePaths: [file], includePath: includePath, kind: .dynamicLibrary)
    }

    /// A dynamic library.
    /// 
    /// - Parameters: 
    ///     - file: Path of the binary relative to the build directory.
    ///     - headers: List of header file paths.
    public static func dynamicLibrary(_ file: String, headers: [String]?) -> Product {
        return Product(filePaths: [file], headers: headers, kind: .dynamicLibrary)
    }


    /// A dynamic library merged from multiple static archives post compilation.
    /// 
    /// - Parameters: 
    ///     - staticArchives: Path of static archives relative to the build directory.
    ///     - binaryName: Custom name for the outputted library. If `nil`, will use the project's name.
    ///     - additionalLinkerFlags: Arguments passed to the linker.
    public static func dynamicLibrary(staticArchives: [String], binaryName: String? = nil, additionalLinkerFlags: [String]? = nil) -> Product {
        return Product(filePaths: staticArchives, binaryName: binaryName, includePath: nil, kind: .staticArchive(mergeIntoDylib: true, additionalLinkerFlags: additionalLinkerFlags))
    }

    /// A dynamic library merged from multiple static archives post compilation.
    /// 
    /// - Parameters: 
    ///     - staticArchives: Path of static archives relative to the build directory.
    ///     - binaryName: Custom name for the outputted library. If `nil`, will use the project's name.
    ///     - includePath: Path of directory containing header files.
    ///     - additionalLinkerFlags: Arguments passed to the linker.
    public static func dynamicLibrary(staticArchives: [String], binaryName: String? = nil, includePath: String? = nil, additionalLinkerFlags: [String]? = nil) -> Product {
        return Product(filePaths: staticArchives, binaryName: binaryName, includePath: includePath, kind: .staticArchive(mergeIntoDylib: true, additionalLinkerFlags: additionalLinkerFlags))
    }

    /// A dynamic library merged from multiple static archives post compilation.
    /// 
    /// - Parameters: 
    ///     - staticArchives: Path of static archives relative to the build directory.
    ///     - binaryName: Custom name for the outputted library. If `nil`, will use the project's name.
    ///     - headers: List of header file paths.
    ///     - additionalLinkerFlags: Arguments passed to the linker.
    public static func dynamicLibrary(staticArchives: [String], binaryName: String? = nil, headers: [String]?, additionalLinkerFlags: [String]? = nil) -> Product {
        return Product(filePaths: staticArchives, binaryName: binaryName, headers: headers, kind: .staticArchive(mergeIntoDylib: true, additionalLinkerFlags: additionalLinkerFlags))
    }
}