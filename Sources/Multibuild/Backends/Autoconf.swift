import MachO
import Foundation

/// Generating and running Makefiles with Autoconf.
/// Use ``Make`` if the Makefile is already present in the root of the project directory.
public struct Autoconf: Builder {

    /// Target specific flags passed to the compiler.
    public var additionalCompilerFlags: ((Target) -> [String])?

    /// Target specific flags passed to the configure script.
    public var configureArguments: ((Target) -> [String])?

    /// If not `nil`, will call make for all the specified targets. For example, 'install'.
    /// (The install prefix is already set to the build directory)
    public var makeTargets: [String]?

    /// Initializes the autoconf builder.
    /// 
    /// - Parameters:
    ///     - products: Products of the compilation used for packaging operations.
    ///     - makeTargets: If not `nil`, will call make for all the specified targets.
    ///     - configureArguments: Target specific flags passed to the configure script.
    ///     - environment: Environment variables for a given target.
    ///     - additionalCompilerFlags: Target specific flags passed to the compiler.
    public init(products: [Product],
                makeTargets: [String]? = nil,
                configureArguments: ((Target) -> [String])? = nil,
                environment: ((Target) -> [String:String])? = nil,
                additionalCompilerFlags: ((Target) -> [String])? = nil) {
        self.products = products
        self.makeTargets = makeTargets
        self.configureArguments = configureArguments
        self.environment = environment
        self.additionalCompilerFlags = additionalCompilerFlags
    }

    // MARK: - Builder

    public var products: [Product]
    
    public var environment: ((Target) -> [String:String])?

    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        var flags = (additionalCompilerFlags?(target) ?? []).map({
            "\($0.replacingOccurrences(of: "\"", with: "\\\""))"
        }).joined(separator: " ")

        var autoconfArguments = [String]()

        if String(cString: NXGetLocalArchInfo().pointee.name).lowercased().hasPrefix("arm") {
            autoconfArguments.append("--host=arm-apple-darwin")
        } else {
            autoconfArguments.append("--host=x86_64-apple-darwin")
        }

        if target.isApple && target.systemName == .watchos {
            autoconfArguments.append("--target=ios-cross")
        } else {
            autoconfArguments.append("--target=$TARGET_TRIPLE")
        }

        for arch in target.architectures {
            flags += " -arch \(arch.rawValue) "
        }

        let arguments = (autoconfArguments+(configureArguments?(target) ?? [])).map({
            "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\""
        }).joined(separator: " ")

        var makeCall = makeTargets == nil ? "make" : ""
        for target in makeTargets ?? [] {
            makeCall += "make \(target)\n"
        }

        return """
        PROJECT_DIR="$PWD"
        mkdir -p "\(outputDirectoryPath(for: target))"
        cd "\(outputDirectoryPath(for: target))"
        export CC="iosxcrun --sdk $SDK_NAME clang" 
        export CXX="iosxcrun --sdk $SDK_NAME clang"
        export CPP="$TOOLS_DIR/cpp"
        export CFLAGS="-isysroot $SDK -target $TARGET_TRIPLE \(flags)"
        export CXXFLAGS="-isysroot $SDK -target $TARGET_TRIPLE \(flags)" 
        export LDFLAGS="-isysroot $SDK -target $TARGET_TRIPLE \(flags)"
        export PREFIX="$PWD/../../build/$PLATFORM.$ARCHITECTURE"

        if [ -f "$PROJECT_DIR/autogen.sh" ]; then
            "$PROJECT_DIR/autogen.sh" --disable-dependency-tracking -target $TARGET_TRIPLE
        fi

        configure_path=""
        if [ -f "$PROJECT_DIR/Configure" ]; then
            configure_path="$PROJECT_DIR/Configure"
        elif [ -f "$PROJECT_DIR/configure" ]; then
            configure_path="$PROJECT_DIR/configure"
        fi

        if [ -f "Makefile" ] && [ "\(forceConfigure)" = "false" ]; then
             \(makeCall)
        else
            $configure_path \(arguments) --prefix="$PWD/../../build/$PLATFORM.$ARCHITECTURE" &&
            "$TOOLS_DIR/replace.py" "Makefile" "-static" "" &&
            \(target.systemName == .watchos ? "\"$TOOLS_DIR/replace.py\" \"Makefile\" \"-arch armv7 \" \"\" &&" : "")
            \(makeCall)
        fi
        """
    }
}
