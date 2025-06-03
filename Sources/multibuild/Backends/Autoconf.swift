import MachO
import Foundation

public struct Autoconf: BuildBackend {

    public var additionalCompilerFlags: ((Target) -> [String])?
    
    public var configureArguments: ((Target) -> [String])?

    public var products: [Product]

    public init(products: [Product], configureArguments: ((Target) -> [String])? = nil, additionalCompilerFlags: ((Target) -> [String])? = nil) {
        self.products = products
        self.configureArguments = configureArguments
        self.additionalCompilerFlags = additionalCompilerFlags
    }

    public func outputDirectoryPath(for target: Target) -> String {
        "build/\(target.systemName.rawValue).\(target.architectures.map({ $0.rawValue }).joined(separator: "-"))"
    }

    public func environment(for target: Target) -> [String : String] {
        [:]
    }

    public func buildScript(for target: Target) -> String {
        var flags = (additionalCompilerFlags?(target) ?? []).map({
            "\($0.replacingOccurrences(of: "\"", with: "\\\""))"
        }).joined(separator: " ")

        var autoconfArguments = [String]()
        if target.isApple && target.systemName == .watchos {
            autoconfArguments = [
                "-target", "ios-cross",
            ]
        }

        if String(cString: NXGetLocalArchInfo().pointee.name).lowercased().hasPrefix("arm") {
            autoconfArguments.append("--host=arm-apple-darwin")
        } else {
            autoconfArguments.append("--host=x86_64-apple-darwin")
        }

        for arch in target.architectures {
            flags += " -arch \(arch.rawValue) "
        }

        let arguments = (autoconfArguments+(configureArguments?(target) ?? [])).map({
            "\($0.replacingOccurrences(of: "\"", with: "\\\""))"
        }).joined(separator: " ")
        
        return """
        PROJECT_DIR="$PWD"
        mkdir -p "\(outputDirectoryPath(for: target))"
        cd "\(outputDirectoryPath(for: target))"
        export CC="/usr/bin/clang" 
        export CXX="/usr/bin/clang++"
        export CPP="$TOOLS_DIR/cpp"
        export CFLAGS="-isysroot $SDK -target $TARGET_TRIPLE \(flags)"
        export CXXFLAGS="-isysroot $SDK -target $TARGET_TRIPLE \(flags)" 
        export LDFLAGS="-isysroot $SDK -target $TARGET_TRIPLE \(flags)"
        
        configure_path=""
        if [ -f "$PROJECT_DIR/Configure" ]; then
            configure_path="$PROJECT_DIR/Configure"
        elif [ -f "$PROJECT_DIR/configure" ]; then
            configure_path="$PROJECT_DIR/configure"
        fi

        if [ -f "$PROJECT_DIR/autogen.sh" ]; then
            "$PROJECT_DIR/autogen.sh" --disable-dependency-tracking -target $TARGET_TRIPLE
        fi

        $configure_path \(arguments) --prefix "$PWD/../../build/$PLATFORM.$ARCHITECTURE" &&
        "$TOOLS_DIR/replace.py" "Makefile" "-static" "" &&
        \(target.systemName == .watchos ? "\"$TOOLS_DIR/replace.py\" \"Makefile\" \"-arch armv7 \" \"\" &&" : "")
        make install
        """
    }
}