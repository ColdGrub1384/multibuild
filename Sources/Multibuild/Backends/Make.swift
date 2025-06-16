import MachO
import Foundation

/// Running pre generated Makefiles in the root of the project directory.
/// Use ``Autoconf`` if the Makefile needs to be generated from a `configure` script.
public struct Make: Builder {

    /// Target specific flags passed to the compiler.
    public var additionalCompilerFlags: ((Target) -> [String])?

    /// If not `nil`, will call make for all the specified targets. For example, 'install'.
    /// (The install prefix is already set to the build directory)
    public var makeTargets: [String]?

    /// Initializes the autoconf builder.
    /// 
    /// - Parameters:
    ///     - products: Products of the compilation used for packaging operations.
    ///     - makeTargets: If not `nil`, will call make for all the specified targets.
    ///     - environment: Environment variables for a given target.
    ///     - additionalCompilerFlags: Target specific flags passed to the compiler.
    public init(products: [Product],
                makeTargets: [String]? = nil,
                configureArguments: ((Target) -> [String])? = nil,
                environment: ((Target) -> [String:String])? = nil,
                additionalCompilerFlags: ((Target) -> [String])? = nil) {
        self.products = products
        self.makeTargets = makeTargets
        self.environment = environment
        self.additionalCompilerFlags = additionalCompilerFlags
    }

    // MARK: - Builder

    public var products: [Product]
    
    public var environment: ((Target) -> [String:String])?

    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        let flags = (additionalCompilerFlags?(target) ?? []).map({
            "\($0.replacingOccurrences(of: "\"", with: "\\\""))"
        }).joined(separator: " ")

        var makeCall = makeTargets == nil ? "make" : ""
        for target in makeTargets ?? [] {
            makeCall += "make \(target)\n"
        }

        return """
        PROJECT_DIR="$PWD"
        
        if [ "\(forceConfigure)" = "true" ]; then
            rm -rf "\(outputDirectoryPath(for: target))"
        fi
        
        mkdir -p "\(outputDirectoryPath(for: target))"
        cd "\(outputDirectoryPath(for: target))"
        export CC="iosxcrun --sdk $SDK_NAME clang" 
        export CXX="iosxcrun --sdk $SDK_NAME clang"
        export CPP="$TOOLS_DIR/cpp"
        export CFLAGS="-isysroot $SDK -target $TARGET_TRIPLE \(flags)"
        export CXXFLAGS="-isysroot $SDK -target $TARGET_TRIPLE \(flags)" 
        export LDFLAGS="-isysroot $SDK -target $TARGET_TRIPLE \(flags)"
        export PREFIX="$PWD/../../build/$PLATFORM.$ARCHITECTURE"

        \(makeCall) -C "$PROJECT_DIR"
        """
    }
}
