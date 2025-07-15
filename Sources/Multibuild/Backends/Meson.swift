import Foundation

/// Configurating cross files and compiling with Meson.
public struct Meson: Builder {

    /// Target specific flags passed to the compiler.
    public var additionalCompilerFlags: ((Target) -> [String])?

    public var products: [Product]
    
    public var environment: ((Target) -> [String:String])?

    /// Initializes the Meson builder.
    ///
    /// - Parameters:
    ///     - products: Products of the compilation used for packaging operations.
    ///     - environment: Environment variables for a given target.
    ///     - additionalCompilerFlags: Target specific flags passed to the compiler.
    public init(products: [Product],
                environment: ((Target) -> [String:String])? = nil,
                additionalCompilerFlags: ((Target) -> [String])? = nil) {
        self.products = products
        self.environment = environment
        self.additionalCompilerFlags = additionalCompilerFlags
    }

    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        let commaSeparatedFlags = (additionalCompilerFlags?(target) ?? []).map({
            "'\($0.replacingOccurrences(of: "\'", with: "\\\'"))'"
        }).joined(separator: ", ")

        return """

        if [ "\(forceConfigure)" = "true" ]; then
            rm -rf "\(outputDirectoryPath(for: target))"
        fi

        export ADDITIONAL_COMPILER_FLAGS="\(commaSeparatedFlags)"
        export CC=clang
        export CXX=clang++
        export LD=ld
        export CFLAGS=
        export CXXFLAGS=

        cp "$CROSS_FILE" "$CROSS_FILE.temp"

        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$SDK_NAME' "$SDK_NAME"
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$SDK_PATH' "$SDK"
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$ARCH' "$ARCHITECTURE"
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$TARGET_TRIPLE' "$TARGET_TRIPLE"
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$MINVERSION_FLAG' "$MINVERSION_FLAG"
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$ROOT' "$(dirname "$(dirname "$SDK")")"
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$CPU' "$ARCHITECTURE_RUST"
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$ENDIAN' "$ENDIAN"
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$ADDITIONAL_MESON_PROPERTIES' "$ADDITIONAL_MESON_PROPERTIES"
        "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$ADDITIONAL_COMPILER_FLAGS' "$ADDITIONAL_COMPILER_FLAGS"
        if [ -z "$SUBSYSTEM" ]; then
            "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" "\\nsubsystem = '\\$SUBSYSTEM'" ""
        else
            "$TOOLS_DIR/replace.py" "$CROSS_FILE.temp" '$SUBSYSTEM' "$SUBSYSTEM"
        fi

        unset IPHONEOS_DEPLOYMENT_TARGET
        unset MACOSX_DEPLOYMENT_TARGET
        unset TVOS_DEPLOYMENT_TARGET
        unset WATCHOS_DEPLOYMENT_TARGET

        export MESON_FORCE_BACKTRACE=1
        if [ -z "$MAC_CATALYST" ]; then
            meson setup "\(outputDirectoryPath(for: target))" -Ddocs=false --cross-file "$CROSS_FILE.temp" --native-file "$NATIVE_FILE"
        else
            # Not cross compiling when building for Mac Catalyst
            meson setup -Ddocs=false "\(outputDirectoryPath(for: target))"
        fi

        meson compile -C "\(outputDirectoryPath(for: target))"
        rm "$CROSS_FILE.temp"
        """
    }
}
