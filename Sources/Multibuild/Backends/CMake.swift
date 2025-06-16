import Foundation

/// Generating and running Makefiles with CMake.
public struct CMake: Builder {

    /// A CMake generator.
    public struct Generator {
        
        /// Name of the generator passed with `-G`.
        public var name: String

        /// Program responsible of building the generated project.
        /// Takes the target being compiled to and returns a list of arguments including the program's name.
        public var buildProgram: ((Target) -> [String])

        /// Initializes a CMake generator.
        /// 
        /// - Parameters:
        ///   - name: Name of the generator passed with `-G`.
        ///   - buildProgram: Program responsible of building the generated project.
        public init(name: String, buildProgram: @escaping ((Target) -> [String])) {
            self.name = name
            self.buildProgram = buildProgram
        }

        /// 'Unix Makefiles' generator.
        public static let unixMakefiles = Self(name: "Unix Makefiles", buildProgram: { _ in
            ["make"]
        })

        /// 'Ninja' generator.
        public static let ninja = Self(name: "Ninja", buildProgram: { _ in
            ["ninja"]
        })
    }

    /// CMake generator passed with `-G`.
    public var generator: Generator

    /// CMake options from a target being compiled to.
    public var options: ((Target) -> [String:String])

    public var products: [Product]
    
    public var environment: ((Target) -> [String:String])?

    /// Initializes a CMake builder.
    /// 
    /// - Parameters:
    ///     - products: List of known products used for packaging operations.
    ///     - generator: CMake generator (defaults to 'Unix Makefiles').
    ///     - options: CMake options from a target being compiled to.
    ///     - environment: Environment variables for a given target.
    public init(products: [Product] = [],
                generator: Generator = .unixMakefiles,
                options: ((Target) -> [String:String])? = nil,
                environment: ((Target) -> [String:String])? = nil) {
        self.products = products
        self.generator = generator
        self.options = options ?? { _ in
            [:]
        }
        self.environment = environment
    }

    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        
        var options = [
            "ARCHS": target.architectures.map({ $0.rawValue }).joined(separator: ";"),
            "CMAKE_MACOSX_BUNDLE": "OFF",
            "ENABLE_VISIBILITY": "ON"
        ]
        if target.isApple {
            options["CMAKE_TOOLCHAIN_FILE"] = Bundle.module.path(forResource: "ios.toolchain", ofType: "cmake")
        }
        for option in self.options(target) {
            var value = option.value
            if option.key == "CMAKE_C_FLAGS" || option.key == "CMAKE_CXX_FLAGS" {
                var archs = ""
                for arch in target.architectures {
                    archs += "-arch \(arch.rawValue) "
                }
                value = "-target \(target.triple!) -isysroot \(target.sdkURL!.path) \(value) \(archs)"
            }
            options[option.key] = value
        }

        let buildInvocation = generator.buildProgram(target).map({ "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }).joined(separator: " ")

        let buildDir = outputDirectoryPath(for: target)
        return """
        export CC=
        export CXX=
        export CPP=
        export CFLAGS=
        export CXXFLAGS=
        export LDFLAGS=

        mkdir -p "\(buildDir)"
        if [ -f "\(buildDir)/CMakeCache.txt" ] && [ "\(forceConfigure)" = "false" ]; then
            cd "\(buildDir)" &&
            \(buildInvocation)
        else
            cmake -G "\(generator.name)" -B "\(buildDir)" \(options.map({
                "-D\($0.key)=\"\($0.value.replacingOccurrences(of: "\"", with: "\\\""))\""
            }).joined(separator: " ")) &&
            cd "\(buildDir)" &&
            \(buildInvocation)
        fi
        """
    }
}
