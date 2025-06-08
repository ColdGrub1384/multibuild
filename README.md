# multibuild

A Swift build system for compiling to multiple architectures and sdks supporting multiple build backends.
This library provides types that define projects, configurations and also a command line interface to trigger builds.

(only supports Apple platforms for the moment and not all because that's what I'm testing against currently but I plan to add support for at least Linux / Android)

See the [documentation](https://gatites.no.binarios.cl/emma/cosas/documentaciones/multibuild) for API usage information.

## Installation

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

## Usage

`multibuild` provides types for for constructing projects that work with Autoconf, CMake and other build systems.
The protocol `BuildPlan` provides an entry point for a command line program.

```swift
import multibuild

@main
struct Plan: BuildPlan {
    var platform: Platform = .apple // .iOS + .macCatalyst + ...
    var bundleIdentifierPrefix = "com.myapp"

    var project: Project {
        Project(
            directoryURL: rootURL.appendingPathComponent("openssl"),
            gitVersion: "openssl-3.0.16",
            backend: Autoconf(products: [
                .dynamicLibrary(staticArchives: [
                    "libssl.a", "libcrypto.a"
                ], includePath: "include")
            ], configureArguments: { _ in
                ["-static", ] // ...
            }, additionalCompilerFlags: { _ in
                ["-DHAVE_FORK=0"]
            }))
         // ...
    }
}
```

## Directory structure

Build products will be located under a `build` directory inside the compiled project.
Inside the build directory, each folder is named `sdkname.arch1`. For example, `iphoneos.arm64`. These name correspond to targets you can pass to the cli program.
Xcode frameworks are also created under an `apple.universal` directory.

## CLI usage

```
OVERVIEW: Command line interface for building your projects.

USAGE: build-libraries [--root <root>] [--list-targets] [--list-projects] [--no-compile] [--force-configure] [--target <target> ...] [--project <project> ...]

OPTIONS:
  --root <root>           Common root directory of projects. (defaults to working directory)
  --list-targets          List supported compilation targets and exit.
  --list-projects         List declared projects and exit.
  --no-compile            Skip recompilation and only perform packaging operations.
  -f, --force-configure   Force regenerating Makefiles and other configurations.
  -t, --target <target>   Specify a target to build
  -p, --project <project> Specify a project to build
  -h, --help              Show help information.
```