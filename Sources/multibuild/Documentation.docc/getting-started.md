# Getting started

Learn how to declare and compile projects with `multibuild`. 

To start, create a Swift executable target that will run when you want to compile your libraries and add `multibuild` as a dependency. I've tried creating a build tool plugin but I didn't manage to make it work.
What I do in my Swift Package manifest is looking for Xcode frameworks in the project's directory and include them as `binaryTarget`s if they exist and if not, I download them from my server. And I use `multibuild` as part of the process of building and uploading the binaries to the server.

Adding `multibuild` as a dependency:

```swift
let package = Package(
    name: "build-libraries",
    dependencies: [
        .package(url: "pi@gatites.no.binarios.cl:emmacold/multibuild.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "build-libraries",
            dependencies: ["multibuild"]),
    ]
)
```

## Compiling

Now in your code import `multibuild` and declare the projects to compile. You can use the ``BuildPlan`` protocol that implements a basic structure for executables. See also ``Project``.

Example with OpenSSL:

```swift
import Foundation
import multibuild

@main
struct Plan: BuildPlan {

    // Get path where to find OpenSSL from arguments
    var rootURL: URL {
        let args = ProcessInfo.processInfo.arguments
        guard args.count > 1 else {
            print("Usage: \(URL(fileURLWithPath: args[0]).lastPathComponent) <dependencies-path>")
            exit(1)
        }
        return URL(string: args[1], relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))!
    }

    // Compile for all Apple platforms
    var supportedTargets: [Target] {
        Platform.apple.supportedTargets
    }

    // For Apple frameworks
    var bundleIdentifierPrefix: String {
        "app.pyto"
    }

    // Define proejcts...
    var project: Project {
        Project(
            // URL of project
            directoryURL: rootURL.appendingPathComponent("openssl"),
            // Checkout to version 3.0.16
            gitVersion: "openssl-3.0.16",
            backend: Autoconf(products: [
                // Create dynamic library from libssl.a and libcrypto.a
                .dynamicLibrary(staticArchives: [
                    "libssl.a", "libcrypto.a"
                ], includePath: "include")
            ], configureArguments: { _ in
                // Configure arguments customizable by target
                [
                    "disable-devcryptoeng",
                    "-no-shared",
                    "-no-pinshared",
                    "-no-tests",
                    "-no-asm",
                    "-static"
                ]
            }, additionalCompilerFlags: { _ in
                // Compiler flags customizable by target
                ["-DHAVE_FORK=0"]
            }))

         // You can declare more projects...
    }
}
```