/// Building Python wheels.
public struct Python: BuildBackend {

    public var products: [Product]

    public init(products: [Product] = []) {
        self.products = products
    }

    public func outputDirectoryPath(for target: Target) -> String {
        ""
    }

    public func environment(for target: Target) -> [String : String] {
        [:]
    }

    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        ""
    }
}