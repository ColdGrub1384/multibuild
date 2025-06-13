/// Building Xcode projects (Apple only).
/// You should use a ``TargetConditionalBuilder`` instance and check for ``Target/isApple`` to return an alternative build system.
public struct Xcode: Builder {

    /// Source of an Xcode build.
    public enum Source {

        /// A project.
        case project(String)

        /// A workspace.
        case workspace(String)

        internal var argument: String {
            switch self {
                case .project(let project):
                    return "-project \(project.hasSuffix(".xcodeproj") ? project : "\(project).xcodeproj")"
                case .workspace(let workspace):
                    return "-workspace  \(workspace.hasSuffix(".xcworkspace") ? workspace : "\(workspace).xcworkspace")"
            }
        }
    }

    public var products: [Product]

    /// Source of the Xcode build.
    public var source: Source

    /// Schemes to be compiled.
    public var buildSchemes: [String]

    /// Targets to be compiled.
    public var buildTargets: [String]

    /// Xcode configuration.
    /// (Default value is `"Release"`)
    public var configuration: String

    /// Initializes an Xcode builder.
    /// 
    /// - Parameters:
    ///   - products: List of known products.
    ///   - source: Source of the Xcode build.
    ///   - buildSchemes: Schemes to be compiled.
    ///   - buildTargets: Targets to be compiled.
    ///   - configuration: Xcode configuration. (Default value is `"Release"`)
    public init(products: [Product] = [], source: Source, buildSchemes: [String] = [], buildTargets: [String] = [], configuration: String = "Release") {
        self.products = products
        self.source = source
        self.buildSchemes = buildSchemes
        self.buildTargets = buildTargets
        self.configuration = configuration
    }

    public func buildScript(for target: Target, forceConfigure: Bool) -> String {
        let buildDir = outputDirectoryPath(for: target)
        var script = """
        PROJ_NAME="$(basename "$PWD")"
        export XCRUN="$(which xcrun)"
        export CC=
        export CXX=

        if [ "\(forceConfigure)" = "true" ]; then
            rm -rf "\(buildDir)"
        else
            GLOBIGNORE="\(configuration)-\(target.systemName)"
            mkdir -p "\(buildDir)/\(configuration)-\(target.systemName)"
            mv "\(buildDir)"/*  "\(buildDir)/\(configuration)-\(target.systemName)/" &> /dev/null
        fi

        """
        for scheme in buildSchemes {
            script += """
            eval xcodebuild \(source.argument) \\
            build \\
            -configuration "\(configuration)" \\
            -scheme \(scheme) \\
            $XCODEBUILD_ADDITIONAL_FLAGS \\
            BUILD_DIR="\(buildDir)" &&

            """
        }

        for target in buildTargets {
            script += """
            eval xcodebuild \(source.argument) \\
            build \\
            -configuration "\(configuration)" \\
            -target \(target) \\
            $XCODEBUILD_ADDITIONAL_FLAGS \\
            SYMROOT="\(buildDir)" &&

            """
        }

        script += """
        export exit_code=$?

        if [ -z "$exit_code" ]; then
            exit_code=1
        fi

        mv "\(buildDir)/\(configuration)-\(target.systemName)"/* "\(buildDir)/"
        rm -rf "\(buildDir)/\(configuration)-\(target.systemName)"

        exit $exit_code
        """

        return script
    }
}