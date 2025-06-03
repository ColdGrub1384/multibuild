# Getting started

Learn how to declare and compile projects with `multibuild`. 

To start, create a Swift command line program and add `multibuild` as a dependency. You can use if you wish your executable as a build tool or command plugin.

Example of a `Package.swift` manifest:

```swift
import PackageDescription

let package = Package(
    name: "build-libraries",
    products: [
        .executable(
            name: "build-libraries",
            targets: ["build-libraries"]),
    ],

    dependencies: [
        .package(url: "pi@gatites.no.binarios.cl:emmacold/multibuild.git", branch: "main"),
    ],

    targets:[
        .executableTarget(
            name: "build-libraries",
            dependencies: [
                .target(name: "multibuild")
            ],
        )
    ]
)
```

## Compiling

Now in your code import `multibuild` and declare the projects to compile. To build them, call [one of the variants](project#instance-methods) of `compile(for:universalBuild:)`.

Example:

```swift
import Foundation
import multibuild // Import multibuild

let openssl = Project(
    directoryURL: URL(fileURLWithPath: "/path/to/openssl"),
    gitVersion: "openssl-3.0.16",           // Checkout to this tag
    backend: Autoconf(products: [           // Build with autoconf
        .dynamicLibrary(staticArchives: [   // Declare products
            // Output a dynamic library merged from these two static archives
            "libssl.a", "libcrypto.a"
        ], includePath: "include")          // Include directory
    ], configureArguments: { target in      // Target specific configure options
        var args = ["disable-devcryptoeng", "-no-shared", "-no-pinshared", "-no-tests", "-static"]
        if target.systemName == .watchos {
            args.append("-no-asm")
        }
        return args
    }, additionalCompilerFlags: { target in // Target specific compiler flags
        if 
            (target.systemName == .appletvos || target.systemName == .appletvsimulator || 
                    target.systemName == .watchos || target.systemName == .watchsimulator) {
            return ["-DHAVE_FORK=0"]
        } else {
            return []
        }
    }))

// Compile for all Apple platforms
try! openssl.compile(for: .apple)

// Create universal frameworks
let openSSLFrameworks: [URL] = try! openssl.build.createXcodeFrameworks(bundleIdentifierPrefix: "app.pyto")
```