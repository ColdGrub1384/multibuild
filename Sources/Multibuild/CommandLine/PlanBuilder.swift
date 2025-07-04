/// Block result builder for projects. See ``BuildPlan``.
/// You can decorate your own properties / functions to construct a project from multiple projects.
@resultBuilder
public struct PlanBuilder {
    public static func buildBlock(_ components: Project...) -> Project {
        Project(projects: components)
    }

    public static func buildIf(_ component: Project?) -> Project {
        Project(projects: [])

    }
    public static func buildEither(first: Project) -> Project {
        Project(projects: [first])
    }
    public static func buildEither(second: Project) -> Project {
        Project(projects: [second])
    }
}
