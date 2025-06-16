/// A structure used to construct a platform dependant build system from a target being compiled to.
public struct TargetConditionalBuilder: Builder {

    /// Returns a build system from a target being compiled to.
    public var block: (Target) -> Builder

    public var products: [Product]

    public var environment: ((Target) -> [String : String])? {
        get {
            { target in
                block(target).environment?(target) ?? [:]
            }
        }
        
        set {
            
        }
    }
    
    /// Initializes a platform dependant build system.
    /// 
    /// - Parameters:
    ///     - products: List of known products.
    ///     - block: Returns a build systems from a target being compiled to.
    public init(products: [Product], block: @escaping (Target) -> Builder) {
        self.block = block
        self.products = products
    }

    public func outputDirectoryPath(for target: Target) -> String {
        block(target).outputDirectoryPath(for: target)
    }

    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        block(target).buildScript(for: target, forceConfigure: forceConfigure)
    }
}
