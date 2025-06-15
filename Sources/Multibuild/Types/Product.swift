import Foundation

/// Represents a product of the build abstracted from the target.
/// Products are packaged in the order they are declared so one product can reference another product.
public struct Product {

    /// The kind of compiler output. 
    public enum Kind {
        /// Static archive or object file.
        ///
        /// - Parameters:
        ///     - mergeIntoDylib: If set to to ´true´, will merge along all other decalred static archives into one dynamic libraries.
        ///     - additionalLinkerFlags: A list of flags passed to the linker.
        case staticArchive(mergeIntoDylib: Bool, additionalLinkerFlags: ((Target) -> ([String]))?)

        /// A dynamic library.
        /// (Automatically produces frameworks on Apple targets)
        case dynamicLibrary

        /// A framework bundle. Ignored on non Apple targets.
        /// (Automatically produces frameworks for Apple targets)
        case framework
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
    ///     - path: Path of the binary relative to the build directory.
    ///     - additionalLinkerFlags: Linker flags passed in case of merging libraries.
    public static func staticArchive(_ path: String) -> Product {
        return Product(filePaths: [path], includePath: nil, kind: .staticArchive(mergeIntoDylib: false, additionalLinkerFlags: nil))
    }

    /// A static archive.
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - includePath: Path of directory containing headers.
    ///     - additionalLinkerFlags: Linker flags passed in case of merging libraries.
    public static func staticArchive(_ path: String, includePath: String?) -> Product {
        return Product(filePaths: [path], includePath: includePath, kind: .staticArchive(mergeIntoDylib: false, additionalLinkerFlags: nil))
    }

    /// A static archive.
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - headers: List of header file paths.
    ///     - additionalLinkerFlags: Linker flags passed in case of merging libraries.
    public static func staticArchive(_ path: String, headers: [String]?) -> Product {
        return Product(filePaths: [path], headers: headers, kind: .staticArchive(mergeIntoDylib: false, additionalLinkerFlags: nil))
    }


    /// A dynamic library.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - headers: List of header file paths.
    public static func dynamicLibrary(_ path: String) -> Product {
        return Product(filePaths: [path], includePath: nil, kind: .dynamicLibrary)
    }


    /// A dynamic library.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - includePath: List of header file paths.
    public static func dynamicLibrary(_ path: String, includePath: String?) -> Product {
        return Product(filePaths: [path], includePath: includePath, kind: .dynamicLibrary)
    }

    /// A dynamic library.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - headers: List of header file paths.
    public static func dynamicLibrary(_ path: String, headers: [String]?) -> Product {
        return Product(filePaths: [path], headers: headers, kind: .dynamicLibrary)
    }


    /// A dynamic library merged from multiple static archives and object files post compilation.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - staticArchives: Path of static archives relative to the build directory.
    ///     - objectFiles: Path of object files relative to the build directory.
    ///     - binaryName: Custom name for the outputted library. If `nil`, will use the project's name.
    ///     - additionalLinkerFlags: Arguments passed to the linker.. Can reference paths relative to the build directory.
    public static func dynamicLibrary(staticArchives: [String] = [], objectFiles: [String] = [], binaryName: String? = nil, additionalLinkerFlags: ((Target) -> ([String]))? = nil) -> Product {
        return Product(filePaths: staticArchives+objectFiles, binaryName: binaryName, includePath: nil, kind: .staticArchive(mergeIntoDylib: true, additionalLinkerFlags: additionalLinkerFlags))
    }

    /// A dynamic library merged from multiple static archives and object files post compilation.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - staticArchives: Path of static archives relative to the build directory.
    ///     - objectFiles: Path of object files relative to the build directory.
    ///     - binaryName: Custom name for the outputted library. If `nil`, will use the project's name.
    ///     - includePath: Path of directory containing header files.
    ///     - additionalLinkerFlags: Arguments passed to the linker. Can reference paths relative to the build directory.
    public static func dynamicLibrary(staticArchives: [String] = [], objectFiles: [String] = [], binaryName: String? = nil, includePath: String? = nil, additionalLinkerFlags: ((Target) -> ([String]))? = nil) -> Product {
        return Product(filePaths: staticArchives+objectFiles, binaryName: binaryName, includePath: includePath, kind: .staticArchive(mergeIntoDylib: true, additionalLinkerFlags: additionalLinkerFlags))
    }

    /// A dynamic library merged from multiple static archives and object files post compilation.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - staticArchives: Path of static archives relative to the build directory.
    ///     - objectFiles: Path of object files relative to the build directory.
    ///     - binaryName: Custom name for the outputted library. If `nil`, will use the project's name.
    ///     - headers: List of header file paths.
    ///     - additionalLinkerFlags: Arguments passed to the linker.. Can reference paths relative to the build directory.
    public static func dynamicLibrary(staticArchives: [String] = [], objectFiles: [String] = [], binaryName: String? = nil, headers: [String]?, additionalLinkerFlags: ((Target) -> ([String]))? = nil) -> Product {
        return Product(filePaths: staticArchives+objectFiles, binaryName: binaryName, headers: headers, kind: .staticArchive(mergeIntoDylib: true, additionalLinkerFlags: additionalLinkerFlags))
    }

    /// Framework bundle. Ignored on non Apple targets.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters:
    ///     - path: Path of the framework.
    public static func framework(_ path: String) -> Product {
        Product(filePaths: [path], binaryName: nil, headers: nil, kind: .framework)
    }
}
