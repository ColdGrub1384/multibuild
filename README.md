# multibuild

A Swift build system for projects compiling to multiple architectures and sdks.
This library provides types that define projects, configurations and also a command line interface to trigger builds.

After compiling `multibuild` generates Xcode frameworks and Swift Packages to be used on Apple platforms (non Apple platforms don't support `binaryTarget` and `xcframework`s, so we'll have to use an alternate package manager).

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
            version: .git("openssl-3.0.16"),
            builder: Autoconf(products: [
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

On Apple platforms, this will create a framework called `openssl` (project name) from static archives `libssl.a` and `libcrypto.a`, an universal Xcode framework and a Swift Package archive (contains all the frameworks from a project).

## Directory structure

Build products will be located under a `build` directory inside the compiled project.
Inside the build directory, each folder is named `sdkname.arch1`. For example, `iphoneos.arm64`. These name correspond to targets you can pass to the cli program.
Xcode frameworks are also created under an `apple.universal` directory.

## CLI usage

```
OVERVIEW: Command line interface for building your projects.

USAGE: build-command [--root <root>] [--list-targets] [--list-projects] [--no-compile] [--no-upload] [--no-package] [--force-configure] [--target <target> ...] [--project <project> ...]

OPTIONS:
  --root <root>           Common root directory of projects. (defaults to working directory)
  --list-targets          List supported compilation targets and exit.
  --list-projects         List declared projects and exit.
  --no-compile            Skip recompilation and only perform packaging operations.
  --no-upload             Skip uploading generated packages.
  --no-package            Skip generation of Xcode Frameworks and Swift Packages.
  -f, --force-configure   Force regenerating Makefiles and other configurations.
  -t, --target <target>   Specify a target to build
  -p, --project <project> Specify a project to build
  -h, --help              Show help information.
```