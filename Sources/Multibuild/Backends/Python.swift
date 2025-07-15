import Foundation

/// Building Python wheels.
public struct Python: Builder {

    /// Python build backends.
    public enum Backend {
        
        /// Meson
        case meson
        
        /// Maturin
        case maturin
        
        /// Setuptools\_Rust
        case rust
        
        /// Scikit-Build. Takes target specific CMake flags.
        case scikitBuild((Target) -> [String:String])
        
        /// Default backend with no additional configuration
        case `default`
    }
    
    /// The Python version installed in the build machine.
    /// Executable named 'python<version>' must be present in PATH.
    public enum BuildInterpreter: String {
        
        /// python3.14
        case v314 = "3.14"
        
        /// python3.13
        case v313 = "3.13"
        
        /// python3.12
        case v312 = "3.12"
        
        /// python3.11
        case v311 = "3.11"
        
        /// python3.10
        case v310 = "3.10"
        
        /// python3.9
        case v39 = "3.9"
        
        /// python3.8
        case v38 = "3.8"
    }
    
    /// Information of the target Python version.
    public struct TargetInterpreter {
        
        /// Linker flags.
        public var linkerFlags: [String]
        
        /// Location of C API header files.
        public var includeURL: URL
        
        /// Standard library location.
        public var siteURL: URL
        
        /// Environment variables set at build time.
        public var environment: [String:String]
        
        /// Initializes the target interpreter.
        ///
        /// - Parameters:
        ///     - linkerFlags: Linker flags.
        ///     - includeURL: Location of C API header files.
        ///     - siteURL: Standard library location.
        ///     - environment: Environment variables set at build time.
        public init(linkerFlags: [String],
                    includeURL: URL,
                    siteURL: URL,
                    environment: [String:String] = [:]) {
            self.linkerFlags = linkerFlags
            self.includeURL = includeURL
            self.siteURL = siteURL
            self.environment = environment
        }
    }
    
    public var products: [Product]

    /// Build backend.
    public var backend: Backend
    
    /// The Python version installed in the build machine. Should correspond to `targetInterpreter`.
    public var buildInterpreter: BuildInterpreter
    
    /// Information about the target Python version.
    public var targetInterpreter: ((Target) -> TargetInterpreter)
    
    /// Target specific flags passed to the compiler.
    public var additionalCompilerFlags: ((Target) -> [String])?
    
    /// Target specific build arguments.
    public var additionalArguments: ((Target) -> [String])?
    
    public var environment: ((Target) -> [String : String])?
    
    /// Initializes the Python builder.
    ///
    /// - Parameters:
    ///     - backend: Build backend.
    ///     - buildInterpreter: The Python version installed in the build machine.
    ///     - targetInterpreter: Information about the target Python version.
    ///     - additionalCompilerFlags: Target specific flags passed to the compiler.
    ///     - additionalArguments: Target specific build arguments.
    public init(backend: Backend,
                buildInterpreter: BuildInterpreter,
                targetInterpreter: @escaping ((Target) -> TargetInterpreter),
                additionalCompilerFlags: ((Target) -> [String])? = nil,
                additionalArguments: ((Target) -> [String])? = nil) {

        self.products = []
        self.backend = backend
        self.buildInterpreter = buildInterpreter
        self.targetInterpreter = targetInterpreter
        self.additionalCompilerFlags = additionalCompilerFlags
        self.additionalArguments = additionalArguments
        self.environment = { target in
            var dict = targetInterpreter(target).environment
            dict["PYTHON_HEADERS"] = targetInterpreter(target).includeURL.path
            dict["PYTHON_LINK"] = targetInterpreter(target).linkerFlags.map({ "'\($0)'" }).joined(separator: ", ")
            dict["SOABI"] = target.pythonSOABI(version: .custom(buildInterpreter.rawValue))
            dict["PYTHON_CROSS_COMPILING"] = "1"
            dict["PYTHON_PLATFORM"] = target.soabiPlatform
            dict["PYTHON_TARGET_PATH"] = targetInterpreter(target).siteURL.path
            switch target.systemName {
            case .iphoneos, .iphonesimulator:
                dict["PYTHON_SYSTEM"] = "iOS"
            case .watchos, .watchsimulator:
                dict["PYTHON_SYSTEM"] = "watchOS"
            case .appletvos, .appletvsimulator:
                dict["PYTHON_SYSTEM"] = "tvOS"
            case .maccatalyst:
                dict["PYTHON_SYSTEM"] = "MacCatalyst"
            }
            
            for file in (try? FileManager.default.contentsOfDirectory(atPath: targetInterpreter(target).siteURL.path)) ?? [] {
                if file.hasPrefix("_sysconfigdata__") {
                    dict["_PYTHON_SYSCONFIGDATA_NAME"] = file.components(separatedBy: ".")[0]
                    dict["_PYTHON_SYSCONFIGDATA_PATH"] = targetInterpreter(target).siteURL.path
                    break
                }
            }
            
            return dict
        }
    }
    
    public func outputDirectoryPath(for target: Target) -> String {
        switch backend {
        case .maturin:
            "target/wheels"
        case .meson, .rust, .default, .scikitBuild(_):
            "dist"
        }
    }
    
    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        let flags = (additionalCompilerFlags?(target) ?? []).map({
            "\($0.replacingOccurrences(of: "\"", with: "\\\""))"
        }).joined(separator: " ")
        var commaSeparatedFlags = (additionalCompilerFlags?(target) ?? []).map({
            "'\($0.replacingOccurrences(of: "\'", with: "\\\'"))'"
        }).joined(separator: ", ")
        if commaSeparatedFlags.isEmpty {
            commaSeparatedFlags = "''"
        }
        
        let buildCall: String
        
        switch backend {
        case .meson:
            buildCall = "MESON_BUILD_PYTHON"
        case .maturin:
            buildCall = "MATURIN_BUILD"
        case .rust:
            buildCall = "RUST_BUILD"
        case .scikitBuild(let opts):
            var additionalPrefixPath = ""
            var options = [
                "ARCHS": target.architectures.map({ $0.rawValue }).joined(separator: ";"),
                "CMAKE_MACOSX_BUNDLE": "OFF",
                "ENABLE_VISIBILITY": "ON"
            ]
            if target.isApple {
                options["CMAKE_TOOLCHAIN_FILE"] = Bundle.module.path(forResource: "ios.toolchain", ofType: "cmake")
            }
            for option in opts(target) {
                var value = option.value
                if option.key == "CMAKE_C_FLAGS" || option.key == "CMAKE_CXX_FLAGS" {
                    var archs = ""
                    for arch in target.architectures {
                        archs += "-arch \(arch.rawValue) "
                    }
                    value = "-target \(target.triple!) -isysroot \(target.sdkURL!.path) \(value) \(archs)"
                }
                if option.key == "CMAKE_PREFIX_PATH" {
                    additionalPrefixPath = option.value
                    continue
                }
                options[option.key] = value
            }
            
            buildCall = """
            if [ -z "\(additionalPrefixPath.replacingOccurrences(of: "\"", with: "\\\""))" ]; then
                true
            else
                export CMAKE_PREFIX_PATH="\(additionalPrefixPath.replacingOccurrences(of: "\"", with: "\\\""))"
            fi

            ADDITIONAL_PREFIX_PATH="${PKG_CONFIG_LIBDIR//:/;}"
            if [ -z "$CMAKE_PREFIX_PATH" ]; then
                export CMAKE_PREFIX_PATH="$ADDITIONAL_PREFIX_PATH"
            else
                export CMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH;$ADDITIONAL_PREFIX_PATH"
            fi
            export CMAKE_ARGS='\(options.map({
                "-D\($0.key)=\"\($0.value.replacingOccurrences(of: "\"", with: "\\\""))\""
            }).joined(separator: " ")) -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH"'
            
            python -m pip install git+https://git.gatit.es/pyto/scikit-build.git@0.18.3
            BUILD
            """
        case .default:
            buildCall = "BUILD"
        }
                
        return """
        export CFLAGS="$CFLAGS \(flags)"
        export CXXFLAGS="$CXXFLAGS \(flags)"
        export ADDITIONAL_COMPILER_FLAGS="\(commaSeparatedFlags)"
        
        \(buildCall) \((additionalArguments?(target) ?? []).map({ "\($0.replacingOccurrences(of: "'", with: "\\'"))"}).joined(separator: " "))
        """
    }
}
