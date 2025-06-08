import Foundation

/// Generating and running Makefiles with CMake.
public struct CMake: Builder {

    /// CMake options from a target being compiled to.
    public var options: ((Target) -> [String:String])

    public var products: [Product]

    /// Initializes a CMake builder.
    /// 
    /// - Parameters:
    ///     - products: List of known products used for packaging operations.
    ///     - options: CMake options from a target being compiled to.
    public init(products: [Product] = [], options: ((Target) -> [String:String])? = nil) {
        self.products = products
        self.options = options ?? { _ in
            [:]
        }
    }

    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        
        var options = ["ARCHS": target.architectures.map({ $0.rawValue }).joined(separator: ";")]
        if target.isApple {
            options["CMAKE_TOOLCHAIN_FILE"] = Bundle.module.path(forResource: "Environment/ios-cmake/ios.toolchain", ofType: "cmake")
        }
        for option in self.options(target) {
            options[option.key] = option.value
        }

        let buildDir = outputDirectoryPath(for: target)
        return """
        mkdir -p "\(buildDir)"
        if [ -f "\(buildDir)/Makefile" ] && [ "\(forceConfigure)" = "false" ]; then
            cd "\(buildDir)" &&
            make
        else
            cmake -B "\(buildDir)" \(options.map({
                "-D\($0.key)='\($0.value)'"
            }).joined(separator: " ")) &&
            cd "\(buildDir)" &&
            make
        fi
        """
    }
}