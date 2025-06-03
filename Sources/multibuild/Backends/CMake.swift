import Foundation

public struct CMake: BuildBackend {

    public var options: ((Target) -> [String:String])

    public var products: [Product]

    public init(products: [Product], options: ((Target) -> [String:String])? = nil) {
        self.products = products
        self.options = options ?? { _ in
            [:]
        }
    } 

    public func outputDirectoryPath(for target: Target) -> String {
        "build/\(target.systemName.rawValue).\(target.architectures.map({ $0.rawValue }).joined(separator: "-"))"
    }

    public func environment(for target: Target) -> [String : String] {
        [:]
    }

    public func buildScript(for target: Target) -> String {
        
        var options = ["ARCHS": target.architectures.map({ $0.rawValue }).joined(separator: ";")]
        if target.isApple {
            options["CMAKE_TOOLCHAIN_FILE"] = Bundle.module.path(forResource: "Environment/ios-cmake/ios.toolchain", ofType: "cmake")
        }
        for option in self.options(target) {
            options[option.key] = option.value
        }

        return """
        mkdir -p "\(outputDirectoryPath(for: target))" &&
        cmake -B "\(outputDirectoryPath(for: target))" \(options.map({
            "-D\($0.key)='\($0.value)'"
        }).joined(separator: " ")) &&
        cd "\(outputDirectoryPath(for: target))" &&
        make
        """
    }
}