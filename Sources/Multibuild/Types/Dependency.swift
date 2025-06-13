/// A dependency that will be compiled before compiling the dependant project.
public struct Dependency {

    internal var name: String?

    internal var project: Project?

    /// An error indicating that a dependency was not found.
    public struct NotFoundError: Error {

        /// Name of the dependency.
        public var dependencyName: String
    }

    /// Searches for a previously declare project by the base name of its directory URL.
    /// The project must have been declared before compiling, not necesarily before initializing the dependency.
    /// Compiling will fail if the dependency was not declared.
    /// 
    /// - Throws: NotFoundError 
    ///
    /// - Parameters: 
    ///     - name: Base name of project's URL.
    /// 
    /// - Returns: A dependency to a project.
    public static func name(_ name: String) -> Dependency {
        return Self(name: name, project: nil)
    }

    /// Makes a dependency from a project instance.
    /// 
    /// - Parameters: 
    ///     - project: Project to depend on.
    //
    /// - Returns: A dependency to the given project.
    public static func project(_ project: Project) -> Dependency {
        return Self(name: nil, project: project)
    }
}