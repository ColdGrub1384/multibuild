/// A structure used to construct a platform dependant build backend from a target being compiled to.
public struct TargetConditionalBackend: BuildBackend {

    /// Returns a build backend from a target being compiled to.
    public var block: (Target) -> BuildBackend

    public var products: [Product]

    /// Initializes a platform dependant build backend.
    /// 
    /// - Parameters:
    ///     - products: Products of the compilation.
    ///     - block: Returns a build backend from a target being compiled to.
    public init(products: [Product], block: @escaping (Target) -> BuildBackend) {
        self.block = block
        self.products = products
    }

    public func outputDirectoryPath(for target: Target) -> String {
        block(target).outputDirectoryPath(for: target)
    }

    public func environment(for target: Target) -> [String : String] {
        block(target).environment(for: target)
    }

    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        block(target).buildScript(for: target, forceConfigure: forceConfigure)
    }
}