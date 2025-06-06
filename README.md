# multibuild

A Swift build system for compiling to multiple architectures and sdks supporting multiple build backends.
This library provides types that define projects, configurations and also a command line interface to trigger builds.

(only supports Apple platforms for the moment and not all because that's what I'm testing against currently but I plan to add support for at least Linux / Android)


## Usage

To use this library, create an executable Swift Package target and add `multibuild` as a dependency.

```swift
let package = Package(
    name: "build-libraries",
    dependencies: [
        .package(url: "pi@gatites.no.binarios.cl:emma/multibuild.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "build-libraries",
            dependencies: ["multibuild"]),
    ]
)
```

Now you can define your projects like this:

```swift
@main
struct Plan: BuildPlan {
    var platform: Platform = .apple
    var bundleIdentifierPrefix = "app.pyto"


    var project: Project {
        Project(...)
        Project(...)
    }
}
```

See the [documentation](https://gatites.no.binarios.cl/emma/cosas/documentaciones/multibuild) for API usage information.