# Getting started

Learn how to declare and compile projects with `multibuild`. 

To start, create a Swift executable target that will run when you want to compile your libraries and add `multibuild` as a dependency. I've tried creating a build tool plugin but I didn't manage to make it work.
What I do in my Swift Package manifest is looking for Xcode frameworks in the project's directory and include them as `binaryTarget`s if they exist and if not, I download them from my server. And I use `multibuild` as part of the process of building and uploading the binaries to the server.

Adding `multibuild` as a dependency:

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

## Compiling

Now in your code import `multibuild` and declare the projects to compile. You can use the ``BuildPlan`` protocol that implements a command line interface for building your projects. See also ``Project``.

Example with OpenSSL:

```swift
import Foundation
import multibuild

@main
struct Plan: BuildPlan {

    // Compile for all Apple platforms
    var platform: Platform = .apple

    // For Apple frameworks
    var bundleIdentifierPrefix = "app.pyto"

    // Define proejcts...
    var project: Project {
        Project(
            // URL of project, computed from the --root flag
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

Now you can compile your executable and run it. See ``BuildCommand`` for CLI usage information. 

```
$ swift run build-libraries [--root <root>] [--target <target> ...]
```

## Directory structure

Build products will be located under a `build` directory inside the compiled project.
Inside the build directory, each folder is named `sdkname.arch1`. For example, `iphoneos.arm64`. These name correspond to targets you can pass to the cli program.
Xcode frameworks are also created under an `apple.universal` directory.

## Referencing products

Let's say we are compiling `libssh2` and it depends on `openssl`. In this case we can find the `openssl` build directory and pass it to our CMake options. When building for Apple platforms, `multibuild` will make frameworks from dynamic libraries declared in ``BuildBackend/products`` for us so we can link directly to the target specific framework instead of having to search for the correct subfolder in the Xcode framework inside ``Build/appleUniversalBuildDirectoryURL``. On other other platforms, you should link directly to the shared or static library.

```swift
Project(
    directoryURL: rootURL.appendingPathComponent("libssh2"),
    dependencies: [.name("openssl")], // openssl must be compiled before
    backend: CMake(products: [
        .dynamicLibrary("src/libssh2.dylib", includePath: "../../include")
    ], options: { target in
        var opts = [...]

        guard let openssl = self.build(for: "openssl")?.buildDirectoryURL(for: target) else {
            return opts
        }

        // link to openssl.framework
        let opensslFlags = "-F'\(openssl.path)' -framework openssl"

        opts["CMAKE_C_FLAGS"] = opensslFlags
        opts["CMAKE_CXX_FLAGS"] = opensslFlags
        opts["OPENSSL_INCLUDE_DIR"] = openssl.appendingPathComponent("include").path
        opts["OPENSSL_ROOT_DIR"] = openssl.path

        return opts
    })
)
```