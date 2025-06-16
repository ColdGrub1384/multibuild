# ``Multibuild``

A Swift build system for compiling to multiple architectures and sdks supporting multiple build systems.

After compiling `multibuild` generates Xcode frameworks and Swift Packages to be used on Apple platforms (non Apple platforms don't support `binaryTarget` and `xcframework`s, so we'll have to use an alternate package manager).

This library provides types that define projects, configurations and also a command line interface to trigger builds.
It only supports Apple platforms for the moment and not all because that's what I'm testing against currently but I plan to add support for at least Linux / Android.

See <doc:getting-started>.

## Topics

### Configuring a project

- ``Build``
- ``Dependency``
- ``Framework``
- ``Product``
- ``Platform``
- ``Project``
- ``Target``

### Generating packages

- ``PackageArchive``
- ``PackageUpload``

### Command line interface

- ``BuildCommand``
- ``BuildPlan``
- ``PlanBuilder``

### Build systems

- ``Builder``
- ``TargetConditionalBuilder``
- ``Autoconf``
- ``CMake``
- ``Make``
- ``Python``
- ``Xcode``
