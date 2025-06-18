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

    /// Overriden  install name of a dynamic library.
    public var installName: String?
    
    /// A path of binary libraries.
    public var libraryPaths: [String]

    /// The path of the directory containing the header files of the library.
    public var includePath: String?

    /// A list of header file paths.
    public var headers: [String]?
    
    /// Path of resources to package alonside the binary..
    public var resources: [String]

    /// Kind of binary.
    public var kind: Kind

    internal init(filePaths: [String], binaryName: String? = nil, installName: String? = nil, includePath: String?, resources: [String] = [], kind: Kind) {
        self.libraryPaths = filePaths
        self.binaryName = binaryName
        self.installName = installName
        self.includePath = includePath
        self.resources = resources
        self.kind = kind
    }

    internal init(filePaths: [String], binaryName: String? = nil, installName: String? = nil, headers: [String]?, resources: [String] = [], kind: Kind) {
        self.libraryPaths = filePaths
        self.binaryName = binaryName
        self.installName = installName
        self.headers = headers
        self.resources = resources
        self.kind = kind
    }


    /// A static archive.
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - resources: Path of resources to package alongside the binary relative to the build directory.
    public static func staticArchive(_ path: String, resources: [String] = []) -> Product {
        return Product(filePaths: [path], includePath: nil, resources: resources, kind: .staticArchive(mergeIntoDylib: false, additionalLinkerFlags: nil))
    }

    /// A static archive.
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - includePath: Path of directory containing headers.
    ///     - resources: Path of resources to package alongside the binary relative to the build directory.
    public static func staticArchive(_ path: String, includePath: String?, resources: [String] = []) -> Product {
        return Product(filePaths: [path], includePath: includePath, resources: resources, kind: .staticArchive(mergeIntoDylib: false, additionalLinkerFlags: nil))
    }

    /// A static archive.
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - headers: List of header file paths.
    ///     - resources: Path of resources to package alongside the binary relative to the build directory.
    public static func staticArchive(_ path: String, headers: [String]?, resources: [String] = []) -> Product {
        return Product(filePaths: [path], headers: headers, resources: resources, kind: .staticArchive(mergeIntoDylib: false, additionalLinkerFlags: nil))
    }


    /// A dynamic library.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - installName: Overriden  install name of a dynamic library.
    ///     - resources: Path of resources to package alongside the binary relative to the build directory.
    public static func dynamicLibrary(_ path: String, installName: String? = nil, resources: [String] = []) -> Product {
        return Product(filePaths: [path], installName: installName, includePath: nil, resources: resources, kind: .dynamicLibrary)
    }


    /// A dynamic library.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - installName: Overriden  install name of a dynamic library.
    ///     - includePath: List of header file paths.
    ///     - resources: Path of resources to package alongside the binary relative to the build directory.
    public static func dynamicLibrary(_ path: String, installName: String? = nil, includePath: String?, resources: [String] = []) -> Product {
        return Product(filePaths: [path], installName: installName, includePath: includePath, resources: resources, kind: .dynamicLibrary)
    }

    /// A dynamic library.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - path: Path of the binary relative to the build directory.
    ///     - installName: Overriden  install name of a dynamic library.
    ///     - headers: List of header file paths.
    ///     - resources: Path of resources to package alongside the binary relative to the build directory.
    public static func dynamicLibrary(_ path: String, installName: String? = nil, headers: [String]?, resources: [String] = []) -> Product {
        return Product(filePaths: [path], installName: installName, headers: headers, resources: resources, kind: .dynamicLibrary)
    }


    /// A dynamic library merged from multiple static archives and object files post compilation.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - staticArchives: Path of static archives relative to the build directory.
    ///     - objectFiles: Path of object files relative to the build directory.
    ///     - binaryName: Custom name for the outputted library. If `nil`, will use the project's name.
    ///     - installName: Overriden  install name of a dynamic library.
    ///     - additionalLinkerFlags: Arguments passed to the linker.. Can reference paths relative to the build directory.
    public static func dynamicLibrary(staticArchives: [String] = [],
                                      objectFiles: [String] = [],
                                      binaryName: String? = nil,
                                      installName: String? = nil,
                                      additionalLinkerFlags: ((Target) -> ([String]))? = nil,
                                      resources: [String] = []) -> Product {
        return Product(filePaths: staticArchives+objectFiles, binaryName: binaryName, installName: installName, includePath: nil, resources: resources, kind: .staticArchive(mergeIntoDylib: true, additionalLinkerFlags: additionalLinkerFlags))
    }

    /// A dynamic library merged from multiple static archives and object files post compilation.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - staticArchives: Path of static archives relative to the build directory.
    ///     - objectFiles: Path of object files relative to the build directory.
    ///     - binaryName: Custom name for the outputted library. If `nil`, will use the project's name.
    ///     - installName: Overriden  install name of a dynamic library.
    ///     - includePath: Path of directory containing header files.
    ///     - additionalLinkerFlags: Arguments passed to the linker. Can reference paths relative to the build directory.
    ///     - resources: Path of resources to package alongside the binary relative to the build directory.
    public static func dynamicLibrary(staticArchives: [String] = [],
                                      objectFiles: [String] = [],
                                      binaryName: String? = nil,
                                      installName: String? = nil,
                                      includePath: String? = nil,
                                      additionalLinkerFlags: ((Target) -> ([String]))? = nil,
                                      resources: [String] = []) -> Product {
        return Product(filePaths: staticArchives+objectFiles, binaryName: binaryName, installName: installName, includePath: includePath, resources: resources, kind: .staticArchive(mergeIntoDylib: true, additionalLinkerFlags: additionalLinkerFlags))
    }

    /// A dynamic library merged from multiple static archives and object files post compilation.
    /// (Automatically produces frameworks for Apple targets)
    /// 
    /// - Parameters: 
    ///     - staticArchives: Path of static archives relative to the build directory.
    ///     - objectFiles: Path of object files relative to the build directory.
    ///     - binaryName: Custom name for the outputted library. If `nil`, will use the project's name.
    ///     - installName: Overriden  install name of a dynamic library.
    ///     - headers: List of header file paths.
    ///     - additionalLinkerFlags: Arguments passed to the linker.. Can reference paths relative to the build directory.
    ///     - resources: Path of resources to package alongside the binary relative to the build directory.
    public static func dynamicLibrary(staticArchives: [String] = [], objectFiles: [String] = [], binaryName: String? = nil, installName: String? = nil, headers: [String]?, additionalLinkerFlags: ((Target) -> ([String]))? = nil, resources: [String] = []) -> Product {
        return Product(filePaths: staticArchives+objectFiles, binaryName: binaryName, installName: installName, headers: headers, resources: resources, kind: .staticArchive(mergeIntoDylib: true, additionalLinkerFlags: additionalLinkerFlags))
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
