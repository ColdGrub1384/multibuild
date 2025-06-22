import MachO
import Foundation

/// Custom script running in an environment ready for cross compilation.
public struct Script: Builder {

    /// Content of a script.
    public enum Content {
        
        /// Script from a file URL. Must be executable.
        /// Receives a list or arguments.
        case script(URL, [String] = [])
        
        /// Bash script from string.
        case code(String)
    }
    
    /// Content of the script.
    public var content: Content
    
    /// Initializes the autoconf builder.
    /// 
    /// - Parameters:
    ///     - products: Products of the compilation used for packaging operations.
    ///     - content: Content of the script.
    ///     - environment: Environment variables for a given target.
    public init(products: [Product], content: Content, environment: ((Target) -> [String:String])? = nil) {
        self.products = products
        self.content = content
        self.environment = environment
    }

    // MARK: - Builder

    public var products: [Product]
    
    public var environment: ((Target) -> [String:String])?

    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        let prefix = """
        export BUILD_DIRECTORY=\"\(outputDirectoryPath(for: target).replacingOccurrences(of: "\"", with: "\\\""))\"
        export FORCE_CONFIGURE=\(forceConfigure ? "1" : "0")
        """
        
        switch content {
        case .script(let url, let args):
            return """
            \(prefix)
            \(url.path) \(args.map({ "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }).joined(separator: " "))
            """
        case .code(let string):
            return """
            \(prefix)
            \(string)
            """
        }
    }
}
